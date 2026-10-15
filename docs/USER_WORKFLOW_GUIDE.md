# N-ATLAS Video Localizer: User Guide

This guide explains how to turn an English video into a video with translated speech using the app. No video-editing experience is needed.

## Before you start

- Have an internet connection.
- Make sure the N-ATLAS backend is running. The app sends the video to this server for transcription, translation, voice generation, and video rendering.
- If you were given a backend URL and API key, enter them in **Settings** before starting. Use the complete URL, including `https://`, and the matching key. Tap **Save Changes**.
- Choose an English video. The upload screen lists MP4, MOV, and AVI files and a 200 MB maximum. Videos longer than one minute are shortened automatically; the app keeps the beginning, including only the first minute of audio.

Saving settings only stores them on your device. It does not confirm that the backend is online. If the backend uses a temporary tunnel URL, ask its operator for the current URL when the server restarts.

## Make a localized video

### 1. Start

Open the app and tap **Start Now**.

### 2. Upload your video

On **Upload Video**, tap the upload area and choose a video. Wait for the upload confirmation, then tap **Continue**.

### 3. Choose a language and voice

On **Select Language**, choose the language you want:

- Yoruba
- Igbo
- Hausa
- Nigerian English

Choose a female or male voice, then tap **Continue**. The app sends your video for speech transcription and translates the transcript into the selected language. Wait for both steps to finish.

### 4. Review the translation

Read the translated text on the translation screen. You can edit it directly. Tap **Regenerate Translation** if you want the system to make a new translation. When the wording is ready, tap **Continue**.

### 5. Generate and listen to the voice

On **Generate Voice**, choose a speech speed with the slider, then tap **Generate Voice**. When generation finishes, tap the play button to listen. Adjust the speed and generate again if you want another version. Tap **Continue** when you are happy with the voice.

### 6. Wait for the finished video and preview it

The **Preview Localized Video** screen starts rendering when it opens. A progress message appears while the app creates and downloads the finished video. When the player appears, use its play button to review the generated video.

Tap **Continue to Export** when you are ready to save it. Tap **Render Video Again** if a render failed or you discarded the preview. **Delete Video** asks for confirmation before removing the current selection or downloaded preview from the app.

### 7. Save the video

On **Export Video**, tap **Download Video**. Choose a file name and location in the save dialog. The app saves the localized MP4 to that location and shows a confirmation when it is done.

Tap **Back to Video Preview** to return to the player. **Delete Preview** removes the downloaded preview from the device and returns to the preview screen; it does not delete the backend's copy. Tap **Create Another Video** to clear the current workflow and start over.

## Settings

Tap the gear icon on the home screen to open **API Settings**. Enter the backend's base URL and API key, then tap **Save Changes**. These settings are saved on the device and apply to new requests. Ask the backend operator for the correct values; do not guess them.

## If something goes wrong

- **The app cannot connect:** Check the internet connection and confirm that the backend is running. If it uses a temporary tunnel, check that the saved URL is the current, complete URL.
- **401 Unauthorized:** The saved API key may not match the backend. Re-enter the key provided by the backend operator.
- **404 Job not found:** The backend may have restarted or lost the job while it was processing. Start the localization again while the backend is available.
- **A step is still working:** Keep the app open and wait for its progress message to finish before continuing.

