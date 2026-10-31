"""Read immutable GitHub raw bytes back and verify image/ZIP SHA-256."""
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path
import sys
import urllib.request
import zipfile
import subprocess
import base64
import urllib.error

ROOT=Path(__file__).resolve().parents[2]
P=ROOT/'assets/review/guided_assets/shelf_general_open_r0_v1'
commit=sys.argv[1]
names=['source_original.png','full_source_original.png','products_only_original.png','empty_corrected.png',
       'full_composite_candidate.png','half_composite_candidate.png','three_states_comparison.png',
       'game_full_candidate_zoom1.0.png','game_half_candidate_zoom1.0.png','low_composite_candidate.png',
       'four_states_comparison.png','game_low_candidate_zoom1.0.png']
paths=[(P/n).relative_to(ROOT).as_posix() for n in names]+['generated/asset_packs/shelf_general_open_r0_review_v1.zip']
def api(endpoint):
    return json.loads(subprocess.check_output(['gh','api',endpoint],cwd=ROOT))
tree=api(f'repos/yn217/Convenience_store_Sim/git/trees/{commit}?recursive=1')
remote_blobs={item['path']:item['sha'] for item in tree['tree'] if item['type']=='blob'}
def check(path):
    url=f'https://raw.githubusercontent.com/yn217/Convenience_store_Sim/{commit}/{path}'
    try:
        with urllib.request.urlopen(url,timeout=60) as response: data=response.read()
    except urllib.error.HTTPError as error:
        if error.code!=404: raise
        blob=api('repos/yn217/Convenience_store_Sim/git/blobs/'+remote_blobs[path])
        data=base64.b64decode(blob['content'])
    digest=hashlib.sha256(data).hexdigest()
    expected=hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
    blob_sha=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
    if blob_sha!=remote_blobs[path]: raise RuntimeError('Commit tree mismatch: '+path)
    if digest!=expected: raise RuntimeError('SHA mismatch: '+path)
    archive_files=None
    if path.endswith('.zip'):
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            if archive.testzip() is not None: raise RuntimeError('Corrupt remote ZIP')
            archive_files=len(archive.namelist())
    return {'path':path,'url':url,'sha256':digest,'bytes':len(data),'github_uploaded':True,
            'git_blob_sha':blob_sha,
            'zip_entries_verified':archive_files}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    results=list(pool.map(check,paths))
report={'commit':commit,'status':'verified_readback','files':results,'runtime_approved':False}
(P/'github_readback.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Verified GitHub raw SHA-256 for',len(results),'files including ZIP integrity')
