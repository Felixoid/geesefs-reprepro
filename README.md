# A repo to reproduce https://github.com/yandex-cloud/geesefs/issues/98

## How to run

`bash -x run.sh`

It requires just gnupg, docker and curl to run.

As well, you need `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to connect to `R2_ENDPOINT` `R2_BUCKET`. Everything can be get from the Cloudflare dashboard. `run.sh` script will ask about values only once, and save them into `secrets.sh`.

### Run until catch

To build the binary for the reproducing catch, build the https://github.com/yandex-cloud/geesefs/releases/tag/v0.41.2 with the following patch:

```diff
diff --git a/internal/handles.go b/internal/handles.go
index 62748a3..72867b3 100644
--- a/internal/handles.go
+++ b/internal/handles.go
@@ -206,6 +206,11 @@ func (inode *Inode) SetFromBlobItem(item *BlobItemOutput) {
        // If a file is renamed from a different file then we also don't know its server-side
        // ETag or Size for sure, so the simplest fix is to also ignore this check
        renameInProgress := inode.oldName != ""
+       if renameInProgress {
+               s3Log.Warnf("Conflict almost detected (inode %v): Server-Side ETag or size of %v"+
+                       " (%v, %v) differs from local (%v, %v). File is changed remotely, dropping cache",
+                       inode.Id, inode.FullName(), NilStr(item.ETag), item.Size, inode.knownETag, inode.knownSize)
+       }

        if (item.ETag != nil && inode.knownETag != *item.ETag || item.Size != inode.knownSize) &&
                !patchInProgress && !renameInProgress {
```

And then, the following loop will work unless the bug or fix is reproduced:

```bash
i=1
while ! grep 'server-side' ~/geesefs-reprepro/data/geesefs.log; do bash -x run.sh
 i=$((i+1))
 [ $i -eq 20 ] && exit 0  # don't run infinetely
 grep 'Conflict almost detected' ~/geesefs-reprepro/data/geesefs.log && exit 0  # finish on the fix catched
 echo '############################################################################################'
done
```
