# Demonstration media / 演示媒体

The 60-second English and Chinese demonstrations and the editable HyperFrames project are attached to the [0.4.190 preview release](https://github.com/chobitsX/Twinverse/releases/tag/v0.4.190-preview.1). The repository keeps a lightweight ten-second GIF, a static poster and bilingual nine-frame storyboards; full movies and raw frame sequences are not added to Git history.

The universe opening is captured from **0.4.190 / build 288**; seven unchanged build 287 takes are reused: Milky Way, Solar System, Earth, woodland, reef, a cardiomyocyte and an atomic electron-density illustration. Captured with Godot 4.7.2 Movie Maker, Forward+/Metal, Balanced quality. The scene HUD was hidden for scenic takes; overlays and subtitles were added in HyperFrames 0.8.181. Colors/exposure were left unchanged. Camera motion is scripted and scenes are edited together. Output is 1920×1080, 30 FPS, 60 seconds, silent.

Movie Maker uses fixed simulation steps; the maintainer captured slowly in the background to respect the machine's resource budget. **The video is an edited scenic demonstration, not a real-time performance benchmark or continuous navigation recording.** Scientific illustrations and simplified habitats retain the [documented scientific boundaries](../community/SCIENCE.md).

## Lightweight WebM / WebM轻量版

The release also includes VP9 WebM previews alongside the original H.264 MP4 downloads. Both retain the same 60-second edit, 1920×1080 resolution, 30 FPS, BT.709 color and silent playback.

| Edition / 语言 | MP4 | WebM | Smaller / 减少 | Mean SSIM vs MP4 |
|---|---:|---:|---:|---:|
| English | 51.62 MB | 27.35 MB | 47.0% | 0.9922 |
| 简体中文 | 53.88 MB | 28.14 MB | 47.8% | 0.9920 |

File sizes above use decimal MB. All 1,800 frames of each WebM were decoded and compared against its released MP4. Nine selected scene pairs and native-pixel crops of star fields, captions and dark ocean detail were reviewed. The WebM files are lossy transcodes; the SSIM reference is itself compressed. Keep the original MP4 for broad playback compatibility and the higher-quality reference. Exact hashes, settings and measurements are in [webm-288.json](webm-288.json); release download hashes are in `SHA256SUMS.txt`.

新增WebM轻量预览，MP4原文件继续提供。保持60秒剪辑、1080p30、色彩和字幕；两版各1800帧完整解码与数值比较，九组关键场景及星点、文字、暗部裁切已看。属于有损转码，SSIM以已压缩MP4为参照，不代表无损；下载校验值随Release更新。

To reproduce the preview encoding, use FFmpeg with `libvpx-vp9`:

```sh
ffmpeg -i input.mp4 -map 0:v:0 -an -map_metadata -1 \
  -c:v libvpx-vp9 -b:v 0 -crf 30 -deadline good -cpu-used 4 \
  -row-mt 1 -tile-columns 1 -frame-parallel 1 -lag-in-frames 25 \
  -g 120 -aq-mode 0 -threads 2 -pix_fmt yuv420p \
  -color_range tv -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
  output.webm
```

The source demos are SDR BT.709. These settings preserve that source profile; other source formats need their own color handling.

## Static storyboards / 九帧静态速览

[English storyboard](twinverse-storyboard-288-en.jpg) · [中文九帧图](twinverse-storyboard-288-zh.jpg) · [Frame times and source hashes](storyboard-288.json)

The 3×3 images select eight scenic frames and the AI Coding closing card from the released videos, starting at the universe. The frames are uniformly scaled and arranged with localized short titles; scene colors and exposure are unchanged. The [source record](storyboard-288.json) lists the exact frame numbers, timestamps, movie hashes and image hashes. Both READMEs show the image directly below their Explore heading, with a link to the full-size JPEG.

九宫格选用已发布成片的八张场景画面及 AI 共建片尾，从宇宙结构开始，等比缩放并添加简短标题；场景色彩和曝光保持原样。中英文 README 在“可以探索什么 / Explore”标题下直接展示，点击可查看原尺寸图片，便于不播放视频时浏览。

## Credits and terms

- Twinverse demonstration, scene composition and project-owned art: credit **Twinverse / chobitsX**, https://github.com/chobitsX/Twinverse. Assembled demonstration media: **CC BY 4.0**; code and written captions: **MIT**.
- Underlying models, textures and scientific data retain their original terms. See [LICENSING.md](../../LICENSING.md), [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md) and the [asset inventory](../community/ASSET_INVENTORY.json). This includes NASA-derived Earth imagery and credited generated/third-party assets; the assembled-media license does not replace their terms.
- Noto Serif and Noto Sans SC fonts: [Google Fonts](https://github.com/google/fonts), **SIL Open Font License 1.1**; license files accompany the fonts in the editable bundle.
- GSAP 3.14.2: [standard license](https://gsap.com/standard-license/), retained in the local library header. HyperFrames source/runtime retains its own open-source license.
- No stock footage, generated replacement scene footage, music or voiceover was added.

The editable bundle contains both language entries, local fonts/library, caption files, compressed source takes and exact source hashes/frame ranges. GitHub is the current distribution destination. Prepared platform copy is retained for optional future reuse; no YouTube/Bilibili upload is planned.

## 中文

本次演示的宇宙开场使用288版真实Godot场景，其余七段沿用287版素材，通过固定步进录制、程序化运镜、剪辑和中英文字幕制作，隐藏产品HUD；未生成替代场景、调整素材色彩或添加音轨。60秒1080p成片与可编辑工程放在Release附件，仓库保留10秒轻量动图、静态封面与中英九帧图，便于随版本更新。

录制为降低前台干扰而在后台低速完成，视频不作为实时性能或连续操作证据。教学示意与科学边界保持不变。组装媒体采用CC BY 4.0，署名Twinverse/chobitsX；第三方素材、数据和字体继续遵守各自许可。当前只发布GitHub；YouTube/B站不安排，已有文案供未来选用。
