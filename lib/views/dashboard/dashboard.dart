import 'dart:io';
import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/start_button.dart';

final _userInfoProvider = FutureProvider<(String?, double?)>((ref) async {
  // 跟随 phantomHomeProvider，保证与用户卡片的 VIP 状态/余额保持同步
  final info = await ref.watch(phantomHomeProvider.future);
  if (info == null) return (null, null);
  final expireStr = info.expireDate?.toIso8601String();
  return (
    expireStr == null ? null : expireStr.substring(0, 19).replaceFirst('T', ' '),
    info.balance,
  );
});

Future<String?> _renewVip(int duration) async {
  final username = await preferences.getUsername();
  if (username == null) return '用户未登录';
  // 记录续费前的 VIP 状态，用于区分「叠加续费」与「新开 / 过期重开」
  final oldExpireStr = await preferences.getVExpireDate();
  final oldExpire =
      oldExpireStr == null ? null : DateTime.tryParse(oldExpireStr);
  final wasVip = oldExpire != null && oldExpire.isAfter(DateTime.now());
  try {
    final dio = Dio()
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (uri) => 'DIRECT';
          client.badCertificateCallback = (_, host, cert) => true;
          return client;
        },
      );
    final price = await getVipPrice(duration);
    final res = await dio.put(
      'https://api.immmor.com/api/open-vip',
      data: {'username': username, 'duration': duration, 'price': price},
    );
    if (res.data['code'] == 200) {
      final data = res.data['data'];
      await preferences.setBalance((data['balance'] as num?)?.toDouble());
      await preferences.setVExpireDate(data['v_expire_date']);
      await preferences.setVToken(data['v_token']);
      await markVipRenewed(
        DateTime.tryParse(data['v_expire_date']?.toString() ?? ''),
        wasVip,
      );
      return null;
    }
    return res.data['msg'] ?? '续费失败';
  } catch (e) {
    return '网络错误';
  }
}

class _RenewButton extends ConsumerWidget {
  final int duration;
  final bool isVip;

  const _RenewButton({required this.duration, required this.isVip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<double>(
      future: getVipPrice(duration),
      builder: (context, snapshot) {
        final price = snapshot.data ?? (duration == 365 ? 350.0 : 30.0);
        return ElevatedButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认续费'),
                content: Text('确定要${isVip ? '续费' : '开通'} VIP 吗？\n${duration == 365 ? '年付' : '月付'}：¥$price'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
                ],
              ),
            );
            if (confirm == true && context.mounted) {
              final msg = await _renewVip(duration);
              if (msg == null && context.mounted) {
                ref.invalidate(phantomHomeProvider);
                ref.invalidate(_userInfoProvider);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isVip ? '续费成功' : '开通成功')));
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg ?? '续费失败')));
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: isVip ? Colors.green : Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero),
          child: Text('${duration == 365 ? '年付' : '月付'} ¥$price', style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }
}

typedef _IsEditWidgetBuilder = Widget Function(bool isEdit);

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final key = GlobalKey<SuperGridState>();
  final _isEditNotifier = ValueNotifier<bool>(false);
  final _addedWidgetsNotifier = ValueNotifier<List<GridItem>>([]);

  @override
  dispose() {
    _isEditNotifier.dispose();
    _addedWidgetsNotifier.dispose();
    super.dispose();
  }

  Widget _buildIsEdit(_IsEditWidgetBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _isEditNotifier,
      builder: (_, isEdit, _) {
        return builder(isEdit);
      },
    );
  }

  Future<void> _handleConnection() async {
    // 检查用户是否登录
    final username = await preferences.getUsername();
    if (username == null) {
      if (mounted) {
        final res = await globalState.showMessage(
          title: '提示',
          message: const TextSpan(text: '请先登录再使用连接功能'),
          confirmText: '去登录',
        );
        if (res == true && mounted) {
          showDialog(
            context: context,
            builder: (_) => const LoginDialog(),
          );
        }
      }
      return;
    }

    final coreStatus = ref.read(coreStatusProvider);
    if (coreStatus == CoreStatus.connecting) {
      return;
    }
    final tip = coreStatus == CoreStatus.connected
        ? appLocalizations.forceRestartCoreTip
        : appLocalizations.restartCoreTip;
    final res = await globalState.showMessage(message: TextSpan(text: tip));
    if (res != true) {
      return;
    }
    appController.restartCore();
  }

  List<Widget> _buildActions(bool isEdit) {
    return [
      if (!isEdit)
        Consumer(
          builder: (_, ref, _) {
            final coreStatus = ref.watch(coreStatusProvider);
            return Tooltip(
              message: appLocalizations.coreStatus,
              child: FadeScaleBox(
                alignment: Alignment.centerRight,
                child: coreStatus == CoreStatus.connected
                    ? IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.shade900,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _handleConnection,
                        icon: Icon(Icons.check, fontWeight: FontWeight.w900),
                      )
                    : FilledButton.icon(
                        key: ValueKey(coreStatus),
                        onPressed: _handleConnection,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: switch (coreStatus) {
                            CoreStatus.connecting => null,
                            CoreStatus.connected => Colors.green.shade900,
                            CoreStatus.disconnected =>
                              context.colorScheme.error,
                          },
                          foregroundColor: switch (coreStatus) {
                            CoreStatus.connecting => null,
                            CoreStatus.connected => Colors.white,
                            CoreStatus.disconnected =>
                              context.colorScheme.onError,
                          },
                        ),
                        icon: SizedBox(
                          height: globalState.measure.bodyMediumHeight,
                          width: globalState.measure.bodyMediumHeight,
                          child: switch (coreStatus) {
                            CoreStatus.connecting => Padding(
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: context.colorScheme.onPrimary,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            CoreStatus.connected => Icon(
                              Icons.check_sharp,
                              fontWeight: FontWeight.w900,
                            ),
                            CoreStatus.disconnected => Icon(
                              Icons.restart_alt_sharp,
                              fontWeight: FontWeight.w900,
                            ),
                          },
                        ),
                        label: Text(switch (coreStatus) {
                          CoreStatus.connecting => appLocalizations.connecting,
                          CoreStatus.connected => appLocalizations.connected,
                          CoreStatus.disconnected =>
                            appLocalizations.disconnected,
                        }),
                      ),
              ),
            );
          },
        ),
      if (isEdit)
        ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, addedChildren, child) {
            if (addedChildren.isEmpty) {
              return Container();
            }
            return child!;
          },
          child: IconButton(
            onPressed: () {
              _showAddWidgetsModal();
            },
            icon: Icon(Icons.add_circle),
          ),
        ),
      FadeRotationScaleBox(
        child: isEdit
            ? IconButton(
                key: ValueKey(true),
                icon: Icon(Icons.save, key: ValueKey('save-icon')),
                onPressed: _handleUpdateIsEdit,
              )
            : IconButton(
                key: ValueKey(false),
                icon: Icon(Icons.edit, key: ValueKey('edit-icon')),
                onPressed: _handleUpdateIsEdit,
              ),
      ),
    ];
  }

  void _showAddWidgetsModal() {
    showSheet(
      builder: (_, type) {
        return ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, value, _) {
            return AdaptiveSheetScaffold(
              type: type,
              body: _AddDashboardWidgetModal(
                items: value,
                onAdd: (gridItem) {
                  key.currentState?.handleAdd(gridItem);
                },
              ),
              title: appLocalizations.add,
            );
          },
        );
      },
      context: context,
    );
  }

  Future<void> _handleUpdateIsEdit() async {
    if (_isEditNotifier.value == true) {
      await _handleSave();
    }
    _isEditNotifier.value = !_isEditNotifier.value;
  }

  Future<void> _handleSave() async {
    final currentState = key.currentState;
    if (currentState == null) {
      return;
    }
    if (mounted) {
      await currentState.isTransformCompleter;
      final dashboardWidgets = currentState.children
          .map((item) => DashboardWidget.getDashboardWidget(item))
          .toList();
      ref
          .read(appSettingProvider.notifier)
          .update(
            (state) => state.copyWith(dashboardWidgets: dashboardWidgets),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardStateProvider);
    final columns = max(4 * ((dashboardState.contentWidth / 280).ceil()), 8);
    final spacing = 14.mAp;
    final children = [
      ...dashboardState.dashboardWidgets
          .where(
            (item) => item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addedWidgetsNotifier.value = DashboardWidget.values
          .where(
            (item) =>
                !children.contains(item.widget) &&
                item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget)
          .toList();
    });
    return _buildIsEdit(
      (isEdit) => CommonScaffold(
        title: appLocalizations.dashboard,
        actions: _buildActions(isEdit),
        floatingActionButton: const StartButton(),
        body: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16).copyWith(bottom: 88),
            child: Column(
              children: [
                // 会员状态和余额显示
                Consumer(
                  builder: (_, ref, __) {
                    final userInfoAsync = ref.watch(_userInfoProvider);
                    return userInfoAsync.when(
                      data: (userInfo) {
                        if (isEdit) return const SizedBox.shrink();
                        final (expireDate, balance) = userInfo;
                        final isVip = expireDate != null &&
                            DateTime.tryParse(expireDate)?.isAfter(DateTime.now()) == true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isVip ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isVip ? Icons.diamond : Icons.diamond_outlined, size: 16, color: isVip ? Colors.green : Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(isVip ? 'VIP 到期: $expireDate' : '普通用户', style: TextStyle(fontSize: 12, color: isVip ? Colors.green : Colors.grey)),
                                ],
                              ),
                              if (balance != null) ...[
                                const SizedBox(height: 4),
                                Text('余额: ${balance.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: isVip ? Colors.green.shade700 : Colors.grey.shade700)),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _RenewButton(duration: 30, isVip: isVip),
                                  const SizedBox(width: 8),
                                  _RenewButton(duration: 365, isVip: isVip),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
                isEdit
                    ? SystemBackBlock(
                        child: CommonPopScope(
                          child: SuperGrid(
                            key: key,
                            crossAxisCount: columns,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            children: [
                              ...dashboardState.dashboardWidgets
                                  .where(
                                    (item) => item.platforms.contains(
                                      SupportPlatform.currentPlatform,
                                    ),
                                  )
                                  .map((item) => item.widget),
                            ],
                            onUpdate: () {
                              _handleSave();
                            },
                          ),
                          onPop: (context) {
                            _handleUpdateIsEdit();
                            return false;
                          },
                        ),
                      )
                    : Grid(
                        crossAxisCount: columns,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        children: children,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddDashboardWidgetModal extends StatelessWidget {
  final List<GridItem> items;
  final Function(GridItem item) onAdd;

  const _AddDashboardWidgetModal({required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return DeferredPointerHandler(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Grid(
          crossAxisCount: 8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: items
              .map(
                (item) => item.wrap(
                  builder: (child) {
                    return _AddedContainer(
                      onAdd: () {
                        onAdd(item);
                      },
                      child: child,
                    );
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _AddedContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onAdd;

  const _AddedContainer({required this.child, required this.onAdd});

  @override
  State<_AddedContainer> createState() => _AddedContainerState();
}

class _AddedContainerState extends State<_AddedContainer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_AddedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {}
  }

  Future<void> _handleAdd() async {
    widget.onAdd();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ActivateBox(child: widget.child),
        Positioned(
          top: -8,
          right: -8,
          child: DeferPointer(
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton.filled(
                iconSize: 20,
                padding: EdgeInsets.all(2),
                onPressed: _handleAdd,
                icon: Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
