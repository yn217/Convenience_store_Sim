#!/usr/bin/env python3
"""Prepare official Hunyuan3D-2mv, or run one explicitly authorized GPU job.

prepare: CPU imports, exact official weights download, and sample preprocessing.
sample: official sample 1 -> actual shape GLB; requires --gpu-authorized.
shelf: coherent front/left/back manifest -> FULL only, after sample success.
All output is LOCAL EVALUATION ONLY; commercial adoption remains unapproved.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import traceback
from datetime import datetime, timezone

REPO = Path('/mnt/f/WSL/Pixal3D-project')
OUTPUT_ROOT = REPO / 'build/issue123-image-to-3d/hunyuan2mv'
SOURCE = Path('/mnt/f/WSL/Hunyuan3D-2-upstream')
SOURCE_REVISION = 'f8db63096c8282cb27354314d896feba5ba6ff8a'
WORK = Path('/home/inayut/hunyuan2mv-work')
MODEL_ID = 'tencent/Hunyuan3D-2mv'
SUBFOLDER = 'hunyuan3d-dit-v2-mv'
MODEL_FILES = ('config.yaml', 'model.fp16.safetensors')
VIEWS = ('front', 'left', 'back')
SOURCE_FILES = (
    'LICENSE', 'README.md', 'requirements.txt', 'setup.py',
    'examples/shape_gen_multiview.py', 'hy3dgen/shapegen/pipelines.py',
    'hy3dgen/shapegen/preprocessors.py',
    'hy3dgen/shapegen/models/conditioner.py',
    'hy3dgen/shapegen/models/autoencoders/surface_extractors.py',
)


def sha256(path: Path) -> str:
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def save_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def configure_environment(mode: str) -> dict:
    if sys.platform != 'linux' or os.environ.get('WSL_DISTRO_NAME') != 'Ubuntu-F':
        raise RuntimeError('Use wsl.exe -d Ubuntu-F -u inayut with the dedicated Linux venv')
    if sys.prefix != '/home/inayut/.local/envs/hunyuan2mv':
        raise RuntimeError(f'Wrong Python environment: {sys.prefix}')
    sys.dont_write_bytecode = True
    locations = {
        'HOME': '/home/inayut',
        'TMPDIR': str(WORK / 'tmp'), 'TMP': str(WORK / 'tmp'), 'TEMP': str(WORK / 'tmp'),
        'PIP_CACHE_DIR': str(WORK / 'pip-cache'),
        'XDG_CACHE_HOME': str(WORK / 'cache'),
        'HF_HOME': '/home/inayut/pixal3d-cache/huggingface',
        'HUGGINGFACE_HUB_CACHE': '/home/inayut/pixal3d-cache/huggingface/hub',
        'HF_HUB_CACHE': '/home/inayut/pixal3d-cache/huggingface/hub',
        'HF_ASSETS_CACHE': str(WORK / 'cache/hf-assets'),
        'HF_MODULES_CACHE': str(WORK / 'cache/hf-modules'),
        'NUMBA_CACHE_DIR': str(WORK / 'cache/numba'),
        'CUDA_CACHE_PATH': str(WORK / 'cache/cuda'),
        'TORCH_HOME': str(WORK / 'cache/torch'),
        'TORCH_EXTENSIONS_DIR': str(WORK / 'cache/torch_extensions'),
        'TRITON_CACHE_DIR': str(WORK / 'cache/triton'),
        'TORCHINDUCTOR_CACHE_DIR': str(WORK / 'cache/torchinductor'),
    }
    for key, value in locations.items():
        os.environ[key] = value
        if key != 'HOME':
            Path(value).mkdir(parents=True, exist_ok=True)
    os.environ['HF_HUB_DISABLE_XET'] = '1'
    os.environ['PYTHONDONTWRITEBYTECODE'] = '1'
    os.environ['PATH'] = '/home/inayut/.local/envs/hunyuan2mv/bin:/usr/local/bin:/usr/bin:/bin'
    if mode == 'prepare':
        os.environ['CUDA_VISIBLE_DEVICES'] = ''
    else:
        os.environ['HF_HUB_OFFLINE'] = '1'
        os.environ['TRANSFORMERS_OFFLINE'] = '1'
    tempfile.tempdir = str(WORK / 'tmp')
    return locations


def source_provenance(source: Path) -> dict:
    revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if revision != SOURCE_REVISION:
        raise RuntimeError(f'Unexpected official source revision: {revision}')
    files = {name: sha256(source / name) for name in SOURCE_FILES}
    return {'url': 'https://github.com/Tencent-Hunyuan/Hunyuan3D-2',
            'revision': revision, 'path': str(source), 'file_sha256': files}


def prepare_model(root: Path, revision: str | None) -> dict:
    from huggingface_hub import HfApi, hf_hub_download

    lock_path = root / 'model-lock.json'
    previous = json.loads(lock_path.read_text()) if lock_path.exists() else None
    if previous and revision and previous['revision'] != revision:
        raise ValueError('Existing model lock differs; use the pinned revision in model-lock.json')
    revision = previous['revision'] if previous else revision
    info = HfApi().model_info(MODEL_ID, revision=revision, files_metadata=True)
    files_by_name = {item.rfilename: item for item in info.siblings}
    selected = ('LICENSE', 'NOTICE', 'README.md', *(f'{SUBFOLDER}/{name}' for name in MODEL_FILES))
    save_json(root / 'download-plan.json', {
        'model_id': MODEL_ID, 'revision': info.sha,
        'files': {name: {'bytes': files_by_name[name].size,
                         'official_lfs_sha256': getattr(files_by_name[name].lfs, 'sha256', None)}
                  for name in selected}})
    downloaded = {}
    for name in selected:
        path = Path(hf_hub_download(MODEL_ID, filename=name, revision=info.sha))
        metadata = files_by_name[name]
        expected_sha = getattr(metadata.lfs, 'sha256', None) if metadata.lfs else None
        print(f'Verifying {name}: {path.stat().st_size} bytes', flush=True)
        actual_sha = sha256(path)
        if expected_sha and actual_sha != expected_sha:
            raise RuntimeError(f'Official LFS SHA256 mismatch: {name}')
        downloaded[name] = {'path': str(path), 'bytes': path.stat().st_size,
                            'sha256': actual_sha, 'official_lfs_sha256': expected_sha}
        if name != f'{SUBFOLDER}/model.fp16.safetensors':
            destination = root / 'provenance/model' / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, destination)
    lock = {'model_id': MODEL_ID, 'revision': info.sha, 'subfolder': SUBFOLDER,
            'variant': 'fp16', 'use_safetensors': True, 'files': downloaded,
            'license': 'Tencent Hunyuan3D 2.0 Community License',
            'distribution_status': 'LOCAL EVALUATION ONLY', 'commercial_adoption': 'unapproved'}
    save_json(lock_path, lock)
    return lock


def load_locked_model(root: Path) -> dict:
    lock = json.loads((root / 'model-lock.json').read_text())
    if lock['model_id'] != MODEL_ID or lock['subfolder'] != SUBFOLDER:
        raise ValueError('Unexpected model lock')
    for item in lock['files'].values():
        path = Path(item['path'])
        if not path.is_file() or path.stat().st_size != item['bytes'] or sha256(path) != item['sha256']:
            raise RuntimeError(f'Prepared model file changed or is absent: {path}')
    return lock


def sample_views(source: Path) -> dict[str, Path]:
    return {view: source / f'assets/example_mv_images/1/{view}.png' for view in VIEWS}


def preprocess(views: dict[str, Path], destination: Path, config: dict) -> tuple[dict, dict]:
    import numpy as np
    from PIL import Image
    from hy3dgen.shapegen.preprocessors import MVImageProcessorV2

    if tuple(views) != VIEWS:
        raise ValueError('Provide the coherent front, left, back view set in that order')
    image_config = config['image_processor']
    if image_config['target'] != 'hy3dgen.shapegen.preprocessors.MVImageProcessorV2':
        raise ValueError('The checkpoint is not configured for multiview preprocessing')
    processor = MVImageProcessorV2(**image_config['params'])
    images, inputs = {}, {}
    for view, path in views.items():
        with Image.open(path) as original:
            image = original.convert('RGBA')
        alpha = image.getchannel('A')
        if alpha.getbbox() is None:
            raise ValueError(f'Empty foreground: {path}')
        images[view] = image
        rgba_path = destination / 'inputs_rgba' / f'{view}.png'
        rgba_path.parent.mkdir(parents=True, exist_ok=True)
        image.save(rgba_path)
        inputs[view] = {'source_path': str(path), 'source_sha256': sha256(path),
                        'size': list(image.size), 'alpha_extrema': list(alpha.getextrema()),
                        'alpha_bbox': list(alpha.getbbox()), 'rgba_path': str(rgba_path),
                        'rgba_sha256': sha256(rgba_path)}
    if len({data['source_sha256'] for data in inputs.values()}) != 3:
        raise ValueError('Identical files cannot stand in for different camera views')
    processed = processor(images)
    qa_dir = destination / 'preprocess_qa'
    qa_dir.mkdir(parents=True, exist_ok=True)
    for index, view in enumerate(VIEWS):
        array = processed['image'][0, index].permute(1, 2, 0).numpy()
        Image.fromarray(np.clip((array + 1) * 127.5, 0, 255).astype(np.uint8)).save(qa_dir / f'{view}.png')
    details = {'inputs': inputs, 'image_processor': image_config,
               'tensor_shape': list(processed['image'].shape),
               'view_indices': list(processed['view_idxs']),
               'background_removal': 'none; upstream RGBA/alpha recenter, white composite',
               'view_synthesis_or_mirroring': False}
    save_json(destination / 'inputs.json', details)
    return images, details


def shelf_manifest(path: Path | None) -> tuple[dict, dict]:
    if path is None:
        raise ValueError('localblocked: a single hero image is not a coherent multiview input')
    spec = json.loads(path.read_text(encoding='utf-8'))
    if spec['object_id'] != 'shelf_general_FULL' or spec['same_object_geometry'] is not True:
        raise ValueError('Only a coherent shelf_general_FULL view set is supported')
    kind = spec['input_kind']
    if kind not in ('real_multiview', 'controlled_blender_views'):
        raise ValueError('Synthetic independent shelves or mirrored hero images are prohibited')
    if kind == 'controlled_blender_views':
        if spec.get('true_multiview_of_original_mockup') is not False or not spec.get('source_geometry_provenance'):
            raise ValueError('Controlled views must identify geometry and explicitly disclaim original mockup multiview')
    views = {}
    for view in VIEWS:
        candidate = Path(spec['views'][view])
        views[view] = (path.parent / candidate).resolve() if not candidate.is_absolute() else candidate
    return views, {'manifest': str(path), 'sha256': sha256(path), 'declared_provenance': spec,
                   'coherence_status': 'declared by input provider; visual review required'}


def verify_glb(path: Path) -> dict:
    import trimesh

    if not path.is_file() or path.stat().st_size <= 20:
        raise RuntimeError(f'Actual GLB not produced: {path}')
    with path.open('rb') as stream:
        magic, version, length = struct.unpack('<4sII', stream.read(12))
    if magic != b'glTF' or version != 2 or length != path.stat().st_size:
        raise RuntimeError('Invalid GLB 2.0 header/length')
    scene = trimesh.load(path, force='scene', process=False)
    if not scene.geometry or not sum(len(mesh.faces) for mesh in scene.geometry.values()):
        raise RuntimeError('GLB contains no mesh faces')
    return {'path': str(path), 'exists': True, 'bytes': path.stat().st_size, 'sha256': sha256(path),
            'geometry_count': len(scene.geometry),
            'vertices': sum(len(mesh.vertices) for mesh in scene.geometry.values()),
            'faces': sum(len(mesh.faces) for mesh in scene.geometry.values()),
            'bounds': scene.bounds.tolist(), 'extents': scene.extents.tolist(),
            'has_uv': any(getattr(mesh.visual, 'uv', None) is not None for mesh in scene.geometry.values()),
            'has_material': any(getattr(mesh.visual, 'material', None) is not None for mesh in scene.geometry.values()),
            'materials': [{'visual_kind': mesh.visual.kind,
                           'material_type': type(getattr(mesh.visual, 'material', None)).__name__}
                          for mesh in scene.geometry.values()],
            'stage': 'shape_only', 'runtime_approved': False}


class Tee:
    def __init__(self, terminal, stream):
        self.terminal, self.stream = terminal, stream

    def write(self, value):
        self.terminal.write(value)
        self.stream.write(value)
        self.stream.flush()
        return len(value)

    def flush(self):
        self.terminal.flush()
        self.stream.flush()


def execute(args, root: Path, record: dict) -> None:
    record['environment'] = configure_environment(args.mode)
    record['source'] = source_provenance(args.source)
    if args.mode == 'prepare':
        for name in SOURCE_FILES:
            destination = root / 'provenance/source' / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(args.source / name, destination)
    sys.path.insert(0, str(args.source))
    import torch
    import yaml
    from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline

    record['packages'] = {name: importlib.metadata.version(name) for name in (
        'torch', 'torchvision', 'transformers', 'tokenizers', 'diffusers', 'huggingface-hub',
        'numpy', 'trimesh', 'scikit-image', 'pymeshlab')}
    record['torch_path'] = torch.__file__
    if args.mode == 'prepare':
        lock = prepare_model(root, args.model_revision)
    else:
        lock = load_locked_model(root)
    record['model'] = lock
    config_path = Path(lock['files'][f'{SUBFOLDER}/config.yaml']['path'])
    config = yaml.safe_load(config_path.read_text())
    record['config'] = config
    if args.mode in ('prepare', 'sample'):
        destination = root / 'official_sample'
        views, input_provenance = sample_views(args.source), {'input_kind': 'official_sample', 'sample_id': '1'}
    else:
        sample_record = json.loads((root / 'official_sample/run.json').read_text())
        if sample_record['status'] != 'success' or sample_record['model']['revision'] != lock['revision']:
            raise RuntimeError('Run the official sample successfully with the same model before the shelf')
        sample_glb = verify_glb(Path(sample_record['output']['path']))
        if sample_glb['sha256'] != sample_record['output']['sha256']:
            raise RuntimeError('Official sample evidence changed')
        views, input_provenance = shelf_manifest(args.views_manifest)
        destination = root / 'shelf_general_FULL'
    images, input_details = preprocess(views, destination, config)
    record['input_provenance'], record['preprocessing'] = input_provenance, input_details
    if args.mode == 'prepare':
        save_json(root / 'shelf-input-status.json', {
            'status': 'localblocked', 'reason': 'Only one corrected_v3 hero is supplied; coherent MV is absent',
            'gpu_inference_started': False, 'stock_state': 'FULL',
            'required_views': list(VIEWS), 'synthetic_back_or_mirrored_front_allowed': False,
            'controlled_blender_views': 'allowed only when declared; not true multiview of the original mockup'})
        record['status'] = 'prepared_waiting_for_gpu_authorization'
        record['gpu_inference_started'] = False
        return
    if not torch.cuda.is_available():
        raise RuntimeError('CUDA unavailable in authorized GPU process')
    torch.cuda.reset_peak_memory_stats()
    record['gpu'] = {'name': torch.cuda.get_device_name(),
                     'total_bytes': torch.cuda.get_device_properties(0).total_memory}
    begin = time.monotonic()
    pipeline = Hunyuan3DDiTFlowMatchingPipeline.from_single_file(
        ckpt_path=lock['files'][f'{SUBFOLDER}/model.fp16.safetensors']['path'],
        config_path=str(config_path), device='cuda', dtype=torch.float16, use_safetensors=True)
    torch.cuda.synchronize()
    record['model_load_seconds'] = time.monotonic() - begin
    begin = time.monotonic()
    record['gpu_inference_started'] = True
    mesh = pipeline(image=images, num_inference_steps=args.steps, octree_resolution=args.octree_resolution,
                    num_chunks=args.num_chunks, guidance_scale=args.guidance_scale,
                    generator=torch.manual_seed(args.seed), output_type='trimesh', mc_algo='mc')[0]
    torch.cuda.synchronize()
    record['inference_seconds'] = time.monotonic() - begin
    if mesh is None:
        raise RuntimeError('Official surface extractor returned no mesh')
    output = destination / 'raw_generated.glb'
    if output.exists():
        raise FileExistsError(f'Refusing to replace existing generated GLB: {output}')
    mesh.export(str(output))
    record['output'] = verify_glb(output)
    record['gpu'].update(peak_allocated_bytes=torch.cuda.max_memory_allocated(),
                         peak_reserved_bytes=torch.cuda.max_memory_reserved())
    record['status'] = 'success'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('mode', choices=('prepare', 'sample', 'shelf'))
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--output-root', type=Path, default=OUTPUT_ROOT)
    parser.add_argument('--model-revision', help='Immutable official Hugging Face commit; locked on prepare')
    parser.add_argument('--views-manifest', type=Path, help='Coherent shelf front/left/back manifest')
    parser.add_argument('--gpu-authorized', action='store_true', help='Use only after parent grants exclusive GPU access')
    parser.add_argument('--seed', type=int, default=12345)
    parser.add_argument('--steps', type=int, default=50)
    parser.add_argument('--octree-resolution', type=int, default=380)
    parser.add_argument('--num-chunks', type=int, default=20000)
    parser.add_argument('--guidance-scale', type=float, default=5.0)
    args = parser.parse_args()
    if args.mode != 'prepare' and not args.gpu_authorized:
        parser.error('GPU inference requires explicit parent permission, then --gpu-authorized')
    root = args.output_root.resolve()
    if not root.is_relative_to(OUTPUT_ROOT.resolve()):
        parser.error('Output must stay inside the authorized hunyuan2mv write set')
    folder = root if args.mode == 'prepare' else root / ('official_sample' if args.mode == 'sample' else 'shelf_general_FULL')
    if args.mode != 'prepare' and (folder / 'raw_generated.glb').exists():
        parser.error('A generated GLB already exists; preserve its run record and use another output-root')
    folder.mkdir(parents=True, exist_ok=True)
    record = {'status': 'running', 'mode': args.mode, 'started_utc': datetime.now(timezone.utc).isoformat(),
              'settings': {key: str(value) if isinstance(value, Path) else value for key, value in vars(args).items()},
              'distribution_status': 'LOCAL EVALUATION ONLY', 'commercial_adoption': 'unapproved',
              'runtime_approved': False, 'gpu_inference_started': False,
              'target_dimensions_m': [0.92, 1.92, 1.5], 'normalization': 'external iso2x_v1; not applied here'}
    started = time.monotonic()
    log_name = 'prepare' if args.mode == 'prepare' else 'run'
    with (folder / f'{log_name}.log').open('a', encoding='utf-8') as stream:
        with contextlib.redirect_stdout(Tee(sys.stdout, stream)), contextlib.redirect_stderr(Tee(sys.stderr, stream)):
            try:
                execute(args, root, record)
            except Exception as error:
                record['status'] = 'error'
                record['error'] = repr(error)
                record['traceback'] = traceback.format_exc()
                print(record['traceback'], file=sys.stderr)
                torch = sys.modules.get('torch')
                if args.mode != 'prepare' and torch is not None and torch.cuda.is_initialized():
                    record.setdefault('gpu', {}).update(peak_allocated_bytes=torch.cuda.max_memory_allocated(),
                                                         peak_reserved_bytes=torch.cuda.max_memory_reserved())
            finally:
                record['elapsed_seconds'] = time.monotonic() - started
                record['finished_utc'] = datetime.now(timezone.utc).isoformat()
                save_json(folder / f'{log_name}.json', record)
    print(json.dumps({'status': record['status'], 'record': str(folder / f'{log_name}.json')}, indent=2))
    return 1 if record['status'] == 'error' else 0


if __name__ == '__main__':
    raise SystemExit(main())
