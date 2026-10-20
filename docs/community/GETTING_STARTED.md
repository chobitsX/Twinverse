# 开始探索 / Getting started

## 先运行项目

macOS可以先下载[0.4.190预览包](https://github.com/chobitsX/Twinverse/releases/tag/v0.4.190-preview.1)，解压后打开`3DWorld.app`，无需安装Godot或配置生成服务密钥。当前为临时签名、未公证的预览，首次打开可能被系统拦截；请核对Release的SHA256SUMS并阅读[Apple的打开应用说明](https://support.apple.com/en-us/102445)，再决定是否允许该应用。包内含Apple Silicon与Intel架构，目前只在M5实测，不能据此保证Intel或低配设备体验。

从源码体验，请按[开发指南](DEVELOPMENT.md)安装固定版本Godot并完成资源导入。源仓库无需本机专用的`builds/macos/current`目录。

程序从宇宙结构全景开始，双击银河入口进入银河系，再探索太阳系与地球。普通启动会保留世界进度与偏好，并从宇宙全景重新出发。你可以先打开“导览”，搜索“宇宙结构”“太阳系”或一个物种；熟悉后直接在3D场景上探索。

## 三条短路线

1. **从宇宙回到家园**：宇宙结构 → 中央银河入口 → 太阳系 → 地球。暂停并拖动视角，比较不同尺度下看见的内容。
2. **走进地球生态**：转动地球，点选海洋、林地、荒漠、城市或两极区域；再次点击、双击或靠近可进入。海洋路径先经过大气与海面。
3. **向生命内部靠近**：在海洋中选择目标鱼，再沿可进入的对象查看器官与细胞参考层。用“知识”了解每一层的简化与依据。

## 常用操作

| 操作 | 输入 |
|---|---|
| 环绕视角 | 鼠标拖动；支持场景中的触控板操作 |
| 靠近/拉远 | 双指捏合或滚轮 |
| 看名称/近看 | 悬停/单击对象 |
| 深入 | 双击或Enter；只有支持进入的对象会切换层级 |
| 返回 | Backspace或顶部路径 |
| 恢复视角 | R |
| 暂停/继续 | Space或底部时间条 |
| 纯净观察 | F9 |
| 取消/关面板 | Esc |

星球近景拉远会先回到太阳系全景，继续新的缩小操作才进入更高尺度。观察不同天体的速度时，注意下方的统一时间倍率；近看自动慢放和手动日期的行为会在界面中提示。

## 画质与设备

右上角“…”可以切换清晰、流畅和节能。默认流畅；节能降低3D渲染分辨率，文字保持清晰。复杂场景第一次进入可能要等待资源/着色器准备。

| 平台 | 目前状态 |
|---|---|
| Apple Silicon Mac | 已有M5 / 32GB机器上的原生功能与有限性能检查 |
| 低配Apple Silicon / 8GB | 待实机验证，不能由M5结果推断 |
| Intel Mac | 导出包含x86_64，尚未实机验收 |
| Windows | 欢迎贡献者测试；尚无已验证的发行包或最低配置 |
| Linux | 尚未验证 |

测试时请报告系统版本、CPU/GPU、内存、画质、窗口尺寸与复现步骤。无需提供设备序列号。没有独立确认的配置不会写成“支持”。

## 保存与教学边界

普通项目运行可保存观察状态和进度。带`--no-save`的体验命令不会写入用户存档；保存文件位于Godot为应用分配的用户数据目录。

宇宙网、银河运动和生态场景包含作者设计，显示亮度/大小也可能作观察增强。暂停和调速不会让这些示意变成精密预测。查看[科学说明](SCIENCE.md)，应用内每个主题也有“依据与边界”。

## English quick route

A [macOS preview ZIP](https://github.com/chobitsX/Twinverse/releases/tag/v0.4.190-preview.1) is available: unzip and open `3DWorld.app`, with no Godot installation or generation-service keys. This ad-hoc-signed, unnotarized build has only been tested on the maintainer’s M5 Mac; Intel and lower-end devices remain unverified. Check the release checksum and [Apple’s guidance](https://support.apple.com/en-us/102445) before deciding whether to allow a blocked first launch.

After importing `project.godot`, run with F5. Use the top navigation/search to find the cosmic web, Solar System, Earth habitats or a species. Drag to orbit; pinch/scroll to zoom; click to inspect; double-click/Enter to enter supported targets. Backspace returns and Space pauses. The interface supports English and Simplified Chinese. Use the top-right “···” menu to choose a language or follow the system; the choice is saved locally. The controls table above follows the same order. The quality menu provides High/Balanced/Energy saving. Use the device-report template to help test unverified platforms.
