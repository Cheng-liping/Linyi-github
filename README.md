# 夸克搜索助手 dylib

微信越狱插件 — 搜索夸克网盘资源，自动转存分享。

## 使用

在微信设置页右上角点「夸克」进入配置：

1. **Cookie** — 从夸克网页版 F12 → Application → Cookies → 全选复制
2. **联系人白名单** — 手动添加微信号 (wxid)，或从最近聊天列表选择

配置完成后，白名单内的联系人即可在聊天框使用：

```
/s 五年级英语     → 搜索资源
/g 0             → 转存第0个结果
/g 衡水体        → 按名称匹配转存
/ck 新Cookie     → 在线更新 Cookie
/list            → 查看白名单
/help            → 帮助
```

## 编译

需要 macOS + Xcode + Theos：

```bash
make package        # 编译打包 deb
make install        # 安装到越狱设备 (需 SSH)
```

## 文件

| 文件 | 说明 |
|------|------|
| `Tweak.xm` | 微信消息钩子 + 设置面板 UI (MobileSubstrate) |
| `QuarkAPI.h` | 夸克 API 接口声明 |
| `QuarkAPI.m` | 夸克 API 客户端 — kuakeso.net 搜索 + quark.cn 转存 |
| `Makefile` | Theos 构建配置 |
| `control` | 包信息 |

## 原理

dylib 注入微信进程 → Hook CMessageMgr 拦截消息 → Hook NewSettingViewController 添加配置入口
→ 调用 kuakeso.net + quark.cn API → 回复消息

设置通过 NSUserDefaults 持久化，无需外部服务器，全程在微信进程内完成。
