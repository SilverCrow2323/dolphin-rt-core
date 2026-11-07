
Downloader
1. Queue format
data/downloads/queue.json:

json
{
  "version": 2,
  "jobs": [
    {
      "id": "unique-id",
      "name": "Display name",
      "url": "https://...",
      "size_mb": 12.0,
      "status": "queued|downloading|awaiting_install|extracting|done|error|cancelled",
      "progress": 0.0,
      "progress_bytes": 0,
      "target": { "kind": "...", "dest": "..." },
      "archive_cleaned": false,
      "error": null
    }
  ]
}
2. Statuses
Status	Meaning
queued	Waiting for a download slot
downloading	curl/wget is pulling the file
awaiting_install	Downloaded, waiting for user to pick a target
extracting	Archive is being extracted
done	Installed
error	Failed
cancelled	Cancelled by user
3. Install targets
downloader.install_choices(entry) reads install_paths (table)
or install_path (string) and returns a list of { key, label, path } options. Keys map to button icons in the target-choice
overlay.

4. Extraction kinds
zip_to_dir: extract into <dest>.

file_to_dir: copy a single file into <dest>.

script: run a shell script.

extract_into is appended to the destination root. extract_ contains is used only for the installed-detection check in
ethostore.lua.

5. Overlay
ui/download_overlay.lua. Opened with R2 (or F9).

Three pages cycled with L1/R1:

QUEUE — active downloads, network probe at the top.

DETAIL — full info for the selected job.

BATCH — bulk actions (cancel all, clean archives, retry
failed, clear completed).

A compact mini bar is drawn by main.lua when the overlay is
closed and a download is active.

6. Retry
DL.retry(id) re-enqueues an errored job. If the API is missing,
the overlay rebuilds the item snapshot and enqueues it fresh.

7. Validation
Downloaded archives are checked for size and basic format before
extraction. A truncated archive is deleted rather than extracted.
