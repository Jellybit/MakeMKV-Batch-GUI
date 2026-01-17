# MakeMKV Batch GUI

A PowerShell-based GUI tool designed to batch process entire seasons of television shows using [MKVToolNix](https://mkvtoolnix.download/) command templates. This is particularly useful when you need to apply identical track changes (renaming, reordering, or merging tracks from different sources) across dozens of files at once.

<img width="875" height="613" alt="image" src="https://github.com/user-attachments/assets/30d0bafc-e6d9-4a09-b70e-a69f144d0024" />

## Why use this?

When managing media libraries, you often find that an entire season of a show needs the same fix—such as forcing a specific subtitle track, reordering audio languages, or muxing high-quality audio from one release into the video of another.

Doing this manually in the MKVToolNix GUI is tedious for 20+ episodes. This tool allows you to set up **one** episode as a template and then "blindly" apply those exact operations to every other episode in the folder.

## Features

* **Template-Based Workflow:** Copy a command line directly from MKVToolNix and use it as a "stamp" for other files.
* **Dual-Input Support:** Easily mux tracks from two different sources (e.g., merging Japanese Video from Source A with English Audio from Source B) across a whole batch.
* **Drag-and-Drop Interface:** Drag files or entire folders directly into the input boxes.
* **Automatic Path Mapping:** Automatically detects and replaces input/output paths within complex mkvmerge commands.
* **Visual Feedback:** The UI grays out and updates the button text during processing so you know the script is working even if the window is "frozen" during a task.
* **Audio Notification:** Plays a system "ding" when the entire batch is finished.

## How to Use

<img width="1497" height="895" alt="image" src="https://github.com/user-attachments/assets/d855b29f-c557-4655-9495-820d9e99510f" />

### 1. Create your Template

1. Open **MKVToolNix GUI**.
2. Drag in your sample files (e.g., Episode 01).
3. Configure your tracks exactly how you want them (reorder, rename, change flags, etc.).
4. In the top menu bar, click on **Multiplexer** and select **Show command line**.
5. Click **Copy to clipboard**.

### 2. Set up the Batcher

1. Paste the command into the **MKVMerge Command Template** box in this tool.
2. **Input 1:** Drag in the group of files (or folder) that corresponds to the **first** file you dragged into MKVToolNix.
3. **Input 2 (Optional):** If your template involved merging two files together, drag the second group of files here.
4. **Output:** Select where you want the new files to be saved.
5. Click **START BATCH PROCESSING**.

## Important Notes

* **Input Order Matters:** Input 1 and Input 2 correspond strictly to the order in which files were added to the MKVToolNix template. If you muxed File A and File B in the template, ensure the "File A" group is in Input 1.
* **Matching Counts:** When using two inputs, the number of files in Input 1 must match the number of files in Input 2. The script processes them in alphabetical order.
* **MKVToolNix Required:** You must have MKVToolNix installed on your system. The script looks for `mkvmerge.exe` based on the path provided in your template command.

## Compile Standalone

To create a standalone executable without the console window, follow these steps in PowerShell:

```powershell
Install-Module ps2exe
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
ps2exe "MakeMKVBatchGUI.ps1" "MakeMKVBatchGUI.exe" -noConsole

```

This installs `ps2exe`, which compiles PowerShell scripts. The execution policy command temporarily allows compilation, reverting when you close the PowerShell window.

---

*Created to make tedious library management a thing of the past.*
