# N-ATLaS Dub: User Guide

Use the app to turn an English MP4 into a video with reviewed Nigerian language speech and subtitles. No video-editing experience is needed.

## Before you start

- Have an internet connection.
- Prepare an MP4 smaller than 100 MB. Videos can be up to 90 seconds; longer uploads are trimmed by the server to 90 seconds.
- Agree to video processing on the upload screen. The app cannot upload without your consent.
- The first request after the server has been idle may take a few minutes while its GPU worker wakes up. Keep the app open while each stage is processing.

The app is configured to use `https://natlas-dub.onrender.com`. Open **Settings** only if you need a different server URL or the server operator has enabled an API key.

## Make a dubbed video

### 1. Upload your video

Tap **Start Now**, accept the processing consent, and choose your MP4. The app checks that the GPU worker is online, uploads the video, and shows the job ID and upload result. If the clip is longer than 90 seconds, the server trims it.

### 2. Choose a language and voice

Choose **Yoruba**, **Hausa**, or **Igbo**, then select a female or male voice. You can optionally enter names or brand terms, separated by commas, that should stay unchanged. Tap **Continue** to start transcription and translation. This background step may take about a minute for a one-minute clip.

### 3. Review translated segments

The review screen shows each original sentence beside its translated segment. Edit wording as needed, then tap **Save & approve** for individual segments, or tap **Approve All & Continue to Voice** to save all edits and approve the full script.

### 4. Generate and listen to the voice

Choose a speech speed from 0.65× to 1.25× and tap **Generate Voice**. Voice generation can take four to five minutes for a one-minute clip. When it finishes, use the play button to listen, then tap **Continue**.

### 5. Render and preview the video

Choose whether to show subtitles, select their top or bottom position, and optionally enable background audio. The app renders the final video and downloads it for preview. Rendering usually takes about 13 seconds after voice generation is complete.

### 6. Download your files

On **Export Video**, choose any files you want to keep:

- Final MP4 video
- Dubbed WAV audio
- SRT subtitles
- Original uploaded video

Jobs are temporary and can disappear when the GPU worker sleeps after inactivity. Download anything you need as soon as it is ready.

## Settings and About

The home screen’s gear opens **API Settings**. The live server URL is filled in by default. Leave the API key blank unless the server operator enables authentication and gives you a key; when configured, the app sends it in the `X-API-Key` header on `/api` requests.

The home screen’s information button opens **About N-ATLaS Dub**.

## If something goes wrong

- **The worker is offline or waking up:** Wait briefly, then try again. The first job after idle may take about three minutes to warm up.
- **413, video too large:** Choose an MP4 under 100 MB.
- **429, too many uploads:** Wait a few minutes before retrying.
- **502 or 503:** The GPU worker may be waking up. Wait briefly and retry.
- **404, job not found:** The temporary job may have expired after the worker went idle. Start again and download results promptly.

