"""Create review-only handoff manifests using the Issue #163 candidate schema."""
import hashlib
import json
from pathlib import Path
import zipfile
import jsonschema

ROOT=Path(__file__).resolve().parents[2]
P=ROOT/'assets/review/guided_assets/shelf_general_open_r0_v1'
schema=json.loads((P/'asset_candidate.schema.json').read_text(encoding='utf-8'))
guide=json.loads((P/'guide.json').read_text(encoding='utf-8'))
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
receipt_path=P/'github_readback.json'
receipt=json.loads(receipt_path.read_text(encoding='utf-8')) if receipt_path.exists() else {}
verified={f['path']:f for f in receipt.get('files',[])}
for state,original,sprite in [('EMPTY','source_original.png','empty_corrected.png'),('LOW','products_only_original.png','low_composite_candidate.png'),('MEDIUM','products_only_original.png','half_composite_candidate.png'),('FULL','full_source_original.png','full_composite_candidate.png')]:
    f=P/original
    outputs=[]
    for name,role in [(original,'source_original'),(sprite,'sprite_fullres'),('four_states_comparison.png','qa_overlay')]:
        target=P/name
        outputs.append({'role':role,'path':target.relative_to(ROOT).as_posix(),'byte_size':target.stat().st_size,
                        'sha256':sha(target),'git_blob_sha':None,'github_uploaded':False})
        remote=verified.get(outputs[-1]['path'])
        if remote and remote['sha256']==outputs[-1]['sha256']:
            outputs[-1].update(git_blob_sha=remote['git_blob_sha'],github_uploaded=True)
    data={'schema_version':1,'asset_id':'shelf_general_open_r0_'+state.lower()+'_v1','asset_class':'interior_fixture',
          'requested_subject':'Roofless four-board Japanese convenience-store gondola '+state,
          'actual_subject':'Four-board open shelf '+state+' review candidate',
          'production_method':'layered_2d','stock_state':state,'stock_rendering':'static_review_baked',
          'fixture_type_id':'shelf_general','source':{'path':f.relative_to(ROOT).as_posix(),'unchanged_original':True,'file_size_bytes':f.stat().st_size,'sha256':sha(f)},
          'outputs':outputs,'projection':{'id':'iso2x_v1','rotation':0,'customer_access_edge':'E','checked_in_godot':True,
              'control_points':[],'max_xy_error_source_px':None,'max_z_error_source_px':None},
          'geometry':{'footprint_tiles':[1,2],'dimensions_m':[.92,1.92,1.5],'world_ground_origin_m':[0,0,0],
                      'image_anchor_px':guide['anchor_px'],'verified':False},
          'quality':{k:'not_checked' for k in ['subject','japanese_fixture_reference','geometry','projection','alpha','state_sync','godot_runtime','human_visual']},
          'github':{'repository':'yn217/Convenience_store_Sim','draft_pr':164,'branch':'art/chatgpt-interior-open-gondola-20261028'},
          'runtime_approved':False}
    data['quality']['subject']='pass'
    data['quality']['notes']=['Local only; PR and branch fields identify intended handoff destination, not upload.',
        'EMPTY shape and FULL density approved to proceed; runtime approval remains false.',
        'Godot screenshots cover r0 at zoom 0.5/1/2, not inventory sync, other rotations or final runtime approval.',
        'Guide vertex numeric checks do not certify generated artwork control points.']
    jsonschema.Draft202012Validator(schema).validate(data)
    (P/(state.lower()+'.candidate.json')).write_text(json.dumps(data,indent=2),encoding='utf-8')
audit={'runtime_approved':False,'shape_approval':'shape_approval.json','stock_states':['EMPTY','LOW','MEDIUM','FULL'],
       'github_readback_commit':receipt.get('commit'),'status':'review_only','files':{f.relative_to(P).as_posix():sha(f) for f in P.rglob('*') if f.is_file() and f.name!='handoff_audit.json'}}
(P/'handoff_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
bundle=ROOT/'generated/asset_packs/shelf_general_open_r0_review_v1.zip'
with zipfile.ZipFile(bundle,'w',zipfile.ZIP_DEFLATED) as z:
    for f in P.rglob('*'):
        if f.is_file(): z.write(f,f.relative_to(P.parent))
with zipfile.ZipFile(bundle) as z: assert z.testzip() is None
print('4 candidate manifests validated; review ZIP refreshed; per-file GitHub status recorded')
