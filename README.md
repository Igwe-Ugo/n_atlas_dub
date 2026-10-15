# N-ATLAS Video Localizer

N-ATLAS turns a short English video into a localized video with translated text and generated speech.

For step-by-step instructions, see the [User Workflow Guide](docs/USER_WORKFLOW_GUIDE.md).

The app is integrated with the N-ATLaS Dub API at `https://natlas-dub.onrender.com`. It uploads an MP4 with user consent, processes a background job, supports segment-by-segment translation review, generates Nigerian speech, renders a localized video, and downloads the final video/audio/subtitles/source.

An API key is optional. If server authentication is enabled later, enter the key in Settings; the app sends it as `X-API-Key` on `/api` requests. For the layperson workflow, see the [User Guide](docs/USER_WORKFLOW_GUIDE.md).

Backend source: [KutuDev/natlas-dub](https://github.com/KutuDev/natlas-dub).
