# tos-app-owncast

将 [Owncast](https://github.com/owncast/owncast)(自托管直播服务器,MIT)打包为 [铁威马 TOS](https://www.terra-master.com) 应用中心 **deb 类应用**(x86_64 + aarch64 双架构)。

**这是什么**:TOS deb 元数据壳 + 可复现构建脚本。上游单二进制(Web UI 内嵌,Release zip,UPSTREAM 锁定 SHA256)原样打包,本仓只产出平台元数据、systemd 单元与配置种子 —— 不修改任何上游代码。

| 项目 | 值 |
|---|---|
| 应用 ID | `owncast` |
| 应用形态 | deb 类 · **open_path 外开**(浏览器新标签页) |
| 观看页 | `http://<NAS>:18239`(低延迟 HLS + 内置聊天) |
| 推流入口 | `rtmp://<NAS>:1935/<推流密钥>`(OBS/FFmpeg/任何 RTMP 编码器;密钥首装生成) |
| 服务 | `owncast.service`(专用 `owncast` 系统用户) |
| 配置 | `/etc/owncast/owncast.env`(端口/管理员密码/推流密钥,首装生成,升级保留;0.3.0 起配置持久化进数据库,CLI flags 注入) |
| 数据 | `/var/lib/owncast/data/`(SQLite + HLS 切片) |
| 版本 | 0.3.0(见 [UPSTREAM](UPSTREAM) 锁定) |
| 上游许可证 | MIT(全文见 [LICENSE](LICENSE),义务见 [NOTICE](NOTICE);封装层 MIT) |
| 端口登记 | 18239(观看)/ 1935(RTMP,协议标准端口) |
| 依赖 | ffmpeg(TOS 出厂自带;缺失时 postinst 告警,owncast 无法转码启动) |

## 关键接线决策(上游 config/defaults.go 调研)

**0.3.0 配置已持久化进数据库**,`config.yaml` 不再读取;端口/密钥通过 CLI flags
在启动时注入(unit 的 `--webserverport/--rtmpport/--adminpassword/--streamkey`,
值来自 `/etc/owncast/owncast.env` 首装生成)。因此:

1. `WorkingDirectory=/var/lib/owncast`(data/ 相对),`ReadWritePaths` 白名单;
2. env 种子锁定观看端口 18239 + RTMP 1935,首装生成管理员密码与推流密钥;
3. 管理后台 /admin 用管理员密码登录,后续改动在 Web 内完成(存数据库,升级保留)。

## 目录结构

```
tos-app-owncast/
├── config.ini                          # TOS 平台元数据(open_path 模式)
├── owncast.lang                        # 26 种语言(生成:scripts/make_lang.py)
├── packaging-extras/owncast.env.default# 配置种子(端口/密钥占位)→ /var/lib/owncast/
├── UPSTREAM                            # 版本锁定(zip + SHA256)
├── DEBIAN/                             # control + postinst(生成密钥+ffmpeg 预检)/prerm/postrm
├── init.d/owncast.service              # systemd(cwd 相对布局)
├── images/icons/owncast.svg            # 原创图标(直播镜头)
├── scripts/                            # fetch/build_deb/unpack_check/validate/make_lang/bump
├── build.sh                            # 一键构建 ./build.sh [x86_64|aarch64]
├── LICENSE                             # 上游 MIT 全文
└── NOTICE                              # 归属与许可义务说明
```

## 本地构建

依赖:bash、curl、python3(任意平台;有 dpkg-deb 时自动优先)。

```bash
./build.sh                # 双架构(下载 zip → 校验 → 打包 → 解包验证)
./scripts/validate.py     # 元数据校验
```

产物:`build/output/owncast_<platform>.deb` + `.sha256`(约 8MB,xz 压缩 24MB 二进制)。

## 上架 Checklist(内部奖励计划 · deb 档 60 元)

1. ☐ 推送本仓 GitHub(ericbyz/tos-app-owncast)+ 打 tag `v0.3.0`;
2. ☐ 提交前**刷新查重**(`owncast`,2026-11-16 核验空白;目录无直播品类);
3. ☐ x86_64 与 ARM **分别创建应用**(独立 App ID、同一开发者账号);
4. ☐ 提交 Release 直链 + SHA256 + 上游源码仓 + 本仓构建脚本;
5. ☐ VM 实测:raw dpkg 安装 + 接线,OBS 推流(或 ffmpeg 命令推流)→ 浏览器观看页截图;
6. ☐ 《参与报名表》勾选 deb 档,附仓库链接;
7. ☐ 30 天内维护 Issues 响应。

## 合规声明

- 上游二进制**原样封装**(MIT),未修改任何上游代码,许可证全文随包分发;
- 安装包内容:上游 Release zip 内的二进制 + 本仓元数据,无其他二进制;
- 不收集任何用户数据;配置/数据库/HLS 切片仅存于 NAS 本地;默认不加入 owncast.directory 公共目录。
