import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/models/state.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/proxies/list.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tab.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> {
  final GlobalKey<ProxiesTabViewState> _proxiesTabKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  bool _isTab = false;
  bool _isSearching = false;

  List<Widget> _buildActions() {
    return [
      IconButton(
        onPressed: () async {
          final profiles = ref.read(profilesProvider);
          final currentId = ref.read(currentProfileIdProvider);
          await appController.loadingRun(() async {
            for (final p in profiles) {
              if (p.id == currentId && p.type == ProfileType.url) {
                // 重新请求当前订阅链接
                await appController.updateProfile(p);
                break;
              }
            }
            await appController.updateGroups();
          }, tag: LoadingTag.proxies);
        },
        icon: const Icon(Icons.refresh),
      ),
      if (_isTab)
        IconButton(
          onPressed: () {
            _proxiesTabKey.currentState?.scrollToGroupSelected();
          },
          icon: Icon(Icons.adjust, weight: 1),
        ),
    ];
  }

  Widget? _buildFAB() {
    return _isTab
        ? DelayTestButton(
            onClick: () async {
              await _proxiesTabKey.currentState?.delayTestCurrentGroup();
            },
          )
        : null;
  }

  void _onSearch(String value) {
    ref.read(queryProvider(QueryTag.proxies).notifier).value = value;
  }

  void _exitSearch() {
    _searchController.clear();
    _onSearch('');
    if (_isSearching) {
      setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PHANTOM',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.6,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '代理节点',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.4,
            color: context.colorScheme.onSurfaceVariant.opacity60,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Row(
      children: [
        IconButton(
          onPressed: _exitSearch,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -3),
            child: TextField(
              autofocus: true,
              controller: _searchController,
              onChanged: _onSearch,
              style: context.textTheme.titleMedium,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: appLocalizations.search,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isLoading) {
    final outline = context.colorScheme.outline;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _isSearching ? _buildSearchField() : _buildBrand(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  flex: 0,
                  child: SizedBox(
                    height: 52,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        children: [
                          if (!_isSearching)
                            IconButton(
                              onPressed: () =>
                                  setState(() => _isSearching = true),
                              icon: const Icon(Icons.search),
                            ),
                          ..._buildActions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: outline.withValues(alpha: 0.12)),
          ],
        ),
        // 叠加在分隔线上，避免刷新时占位把下面的节点列表顶下去
        if (isLoading)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(height: 2, child: LinearProgressIndicator()),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      proxiesStyleSettingProvider.select(
        (state) => state.type == ProxiesType.tab,
      ),
      (prev, next) {
        if (prev != next) {
          setState(() {
            _isTab = next;
          });
        }
      },
      fireImmediately: true,
    );
    ref.listenManual(
      currentPageLabelProvider.select((state) => state == PageLabel.proxies),
      (prev, next) {
        if (prev != next && next == false) {
          _exitSearch();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.type),
    );
    final isLoading = ref.watch(loadingProvider(LoadingTag.proxies));
    final body = switch (proxiesType) {
      ProxiesType.tab => ProxiesTabView(key: _proxiesTabKey),
      ProxiesType.list => const ProxiesListView(),
    };
    return Scaffold(
      resizeToAvoidBottomInset: false,
      floatingActionButton: _buildFAB(),
      body: Stack(
        children: [
          SwissBackground(
            accent: context.colorScheme.primary,
            glowAlpha: 0.09,
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: _buildHeader(isLoading),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
