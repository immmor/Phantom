import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: CommonCard(
          type: CommonCardType.filled,
          onPressed: () {},
          radius: 16,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Consumer(
              builder: (_, ref, _) {
                return _DeveloperModeDetector(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: ShapeDecoration(
                          color: context.colorScheme.surfaceContainerHighest,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        padding: EdgeInsets.all(8),
                        child: Transform.translate(
                          offset: Offset(0, -1),
                          child: SvgPicture.asset('assets/images/phantom.svg', width: 34, height: 34),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        appName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        globalState.packageInfo.version,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant.opacity80,
                        ),
                      ),
                    ],
                  ),
                  onEnterDeveloperMode: () {
                    ref
                        .read(appSettingProvider.notifier)
                        .update((state) => state.copyWith(developerMode: true));
                    context.showNotifier(
                      appLocalizations.developerModeEnableTip,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: CommonCard(
          onPressed: () {},
          radius: 12,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              appLocalizations.desc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant.opacity80,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: CommonCard(
          onPressed: () {},
          radius: 12,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: const DeviceInfoView(),
          ),
        ),
      ),
    ];
    return BaseScaffold(
      title: appLocalizations.about,
      body: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: generateListView(items),
      ),
    );
  }
}

class DeviceInfoView extends StatelessWidget {
  const DeviceInfoView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.devices_other,
              size: 18,
              color: context.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '设备信息',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<BaseDeviceInfo>(
          future: DeviceInfoPlugin().deviceInfo,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                '获取设备信息失败：${snapshot.error}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.error,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final entries = _collectDeviceInfo(snapshot.data!);
            return Column(
              children: [
                for (final (label, value) in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            label,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: context
                                      .colorScheme.onSurfaceVariant
                                      .opacity80,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            value,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

List<(String, String)> _collectDeviceInfo(BaseDeviceInfo deviceInfo) {
  final entries = <(String, String)>[];
  void add(String label, Object? value) {
    if (value == null) return;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == '[]') return;
    entries.add((label, text));
  }

  switch (deviceInfo) {
    case AndroidDeviceInfo info:
      add('系统', 'Android');
      add('SDK', info.version.sdkInt);
      add('系统版本', info.version.release);
      add('安全补丁', info.version.securityPatch);
      add('Codename', info.version.codename);
      add('Incremental', info.version.incremental);
      add('BaseOS', info.version.baseOS);
      add('设备型号', info.model);
      add('品牌', info.brand);
      add('制造商', info.manufacturer);
      add('硬件', info.hardware);
      add('产品', info.product);
      add('设备', info.device);
      add('设备名称', info.name);
      add('主板', info.board);
      add('Bootloader', info.bootloader);
      add('Android ID', info.id);
      add('指纹', info.fingerprint);
      add('支持的ABI', info.supportedAbis.join(', '));
      add('32位ABI', info.supported32BitAbis.join(', '));
      add('64位ABI', info.supported64BitAbis.join(', '));
      add('物理设备', info.isPhysicalDevice);
      add('低内存设备', info.isLowRamDevice);
      add('Type', info.type);
      add('主机', info.host);
      add('显示', info.display);
      add('标签', info.tags);
      add('总磁盘', _formatBytes(info.totalDiskSize));
      add('可用磁盘', _formatBytes(info.freeDiskSize));
      add('物理内存', _formatMB(info.physicalRamSize));
      add('可用内存', _formatMB(info.availableRamSize));
    case IosDeviceInfo info:
      add('系统', 'iOS');
      add('系统名称', info.systemName);
      add('系统版本', info.systemVersion);
      add('设备名称', info.name);
      add('设备型号', info.model);
      add('标识符', info.identifierForVendor);
      add('物理设备', info.isPhysicalDevice);
      add('机器标识', info.utsname.machine);
      add('节点', info.utsname.nodename);
      add('发布版本', info.utsname.release);
      add('系统类型', info.utsname.sysname);
      add('版本号', info.utsname.version);
    case MacOsDeviceInfo info:
      add('系统', 'macOS');
      add('系统版本', '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}');
      add('系统发布', info.osRelease);
      add('内核版本', info.kernelVersion);
      add('电脑名称', info.computerName);
      add('主机名', info.hostName);
      add('架构', info.arch);
      add('型号', info.model);
      add('型号名称', info.modelName);
      add('活动CPU', info.activeCPUs);
      add('CPU频率', _formatHz(info.cpuFrequency));
      add('内存', _formatBytes(info.memorySize));
      add('系统GUID', info.systemGUID);
    case WindowsDeviceInfo info:
      add('系统', 'Windows');
      add('系统版本', '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}');
      add('显示版本', info.displayVersion);
      add('发布ID', info.releaseId);
      add('产品名称', info.productName);
      add('版本ID', info.editionId);
      add('CSD', info.csdVersion);
      add('平台ID', info.platformId);
      add('产品类型', info.productType);
      add('BuildLab', info.buildLab);
      add('BuildLabEx', info.buildLabEx);
      add('电脑名称', info.computerName);
      add('用户名', info.userName);
      add('设备ID', info.deviceId);
      add('产品ID', info.productId);
      add('CPU核数', info.numberOfCores);
      add('系统内存', _formatMB(info.systemMemoryInMegabytes));
      add('服务包主版本', info.servicePackMajor);
      add('服务包次版本', info.servicePackMinor);
      add('套件掩码', info.suitMask);
      add('注册所有者', info.registeredOwner);
      add('安装日期', info.installDate.toLocal().toString());
    case LinuxDeviceInfo info:
      add('系统', 'Linux');
      add('发行版名称', info.name);
      add('发行版版本', info.version);
      add('ID', info.id);
      add('ID Like', info.idLike);
      add('版本ID', info.versionId);
      add('变体', info.variant);
      add('变体ID', info.variantId);
      add('美化名称', info.prettyName);
      add('机器ID', info.machineId);
    default:
      add('系统', Platform.operatingSystem);
  }
  return entries;
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '$bytes B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[index]}';
}

String _formatMB(int mb) {
  if (mb <= 0) return '$mb MB';
  return '$mb MB';
}

String _formatHz(int hz) {
  if (hz <= 0) return '$hz Hz';
  const units = ['Hz', 'KHz', 'MHz', 'GHz'];
  var value = hz.toDouble();
  var index = 0;
  while (value >= 1000 && index < units.length - 1) {
    value /= 1000;
    index++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[index]}';
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
