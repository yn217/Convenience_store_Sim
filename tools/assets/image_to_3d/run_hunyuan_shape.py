"""Local-only Hunyuan3D-2.1 fallback, sample then shelf; no texture claim."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--source',required=True)
    p.add_argument('--image',required=True)
    p.add_argument('--out',required=True)
    p.add_argument('--seed',type=int,default=42)
    args=p.parse_args()
    out=Path(args.out); out.mkdir(parents=True,exist_ok=True)
    os.environ.setdefault('HF_HOME','/home/inayut/pixal3d-cache/huggingface')
    os.environ.setdefault('HY3DGEN_MODELS','/home/inayut/pixal3d-cache/hunyuan')
    os.environ.setdefault('ATTN_BACKEND','sdpa')
    sys.path.insert(0,str(Path(args.source)/'hy3dshape'))
    report={'model':'tencent/Hunyuan3D-2.1','stage':'shape_only','seed':args.seed,
            'source_commit':subprocess.check_output(['git','-C',args.source,'rev-parse','HEAD'],text=True).strip(),
            'runtime_approved':False,'status':'RUNNING','license':'Tencent Hunyuan 3D 2.1 Community',
            'distribution':'LOCAL EVALUATION ONLY; regional restrictions apply; do not commit generated meshes to public GitHub'}
    started=time.monotonic()
    try:
        import torch
        from PIL import Image
        from huggingface_hub import HfApi, snapshot_download
        from hy3dshape.pipelines import Hunyuan3DDiTFlowMatchingPipeline
        report.update(torch=torch.__version__,gpu=torch.cuda.get_device_name(0))
        torch.cuda.reset_peak_memory_stats()
        load_start=time.monotonic()
        revision=HfApi().model_info('tencent/Hunyuan3D-2.1').sha
        report['weights_revision']=revision
        local=snapshot_download('tencent/Hunyuan3D-2.1',revision=revision,
            allow_patterns=['hunyuan3d-dit-v2-1/config.yaml','hunyuan3d-dit-v2-1/model.fp16.ckpt'])
        pipeline=Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(local,use_safetensors=False)
        report['load_seconds']=time.monotonic()-load_start
        report['runs']=[]
        for name,path in [('official_sample',Path(args.source)/'assets/demo.png'),('shelf_general_FULL',Path(args.image))]:
            image=Image.open(path).convert('RGBA')
            if image.getchannel('A').getextrema()[0]==255:
                raise ValueError(f'{name}: needs reviewed foreground alpha; background model was not enabled')
            t=time.monotonic()
            mesh=pipeline(image=image,num_inference_steps=30,octree_resolution=384,
                          generator=torch.Generator(device='cuda').manual_seed(args.seed))[0]
            target=out/name;target.mkdir(exist_ok=True)
            raw=target/'raw_generated.glb';mesh.export(str(raw))
            report['runs'].append({'name':name,'input_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'seconds':time.monotonic()-t,'vertices':len(mesh.vertices),'faces':len(mesh.faces),
                'bounds':mesh.bounds.tolist(),'glb':str(raw),'bytes':raw.stat().st_size,
                'sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'texture_stage':'NOT_RUN'})
            (out/'inference_report.json').write_text(json.dumps(report,indent=2)+'\n')
        torch.cuda.synchronize()
        report['peak_allocated_bytes']=torch.cuda.max_memory_allocated()
        report['peak_reserved_bytes']=torch.cuda.max_memory_reserved()
        report['status']='SHAPE_GENERATED_TEXTURE_PENDING'
    except Exception:
        report['status']='FAILED'
        report['error']=traceback.format_exc()
        raise
    finally:
        report['elapsed_seconds']=time.monotonic()-started
        (out/'inference_report.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
