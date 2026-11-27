import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/glass.dart';
import 'package:fl_clash/common/tap_scale.dart';
import 'package:fl_clash/widgets/user_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 商城 Tab：会员 / 流量 / 节点 / 充值。
/// 设计语言与首页统一：瑞士极简排版 + 玻璃拟态 + 低饱和点缀。
class MallView extends ConsumerStatefulWidget {
  const MallView({super.key});

  @override
  ConsumerState<MallView> createState() => _MallViewState();
}

class _MallViewState extends ConsumerState<MallView>
    with TickerProviderStateMixin {
  late final AnimationController _enterController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  MallCategory _category = MallCategory.all;

  static const _cyan = Color(0xFF00F7FF);

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  List<MallProduct> get _products => switch (_category) {
        MallCategory.all => _allProducts,
        _ => _allProducts.where((p) => p.category == _category).toList(),
      };

  void _onBuy(MallProduct product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PurchaseSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVip = ref.watch(
      phantomHomeProvider.select((a) => a.value?.isVip ?? false),
    );
    final accent = isVip ? const Color(0xFFD4AF37) : _cyan;
    return Scaffold(
      body: Stack(
        children: [
          SwissBackground(
            accent: accent,
            alignment: const Alignment(0.1, -0.55),
            radius: 1.15,
            glowAlpha: isVip ? 0.14 : 0.16,
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: _buildPageHeader(),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildHeader(accent),
                      const SizedBox(height: 16),
                      _buildCategories(accent),
                      const SizedBox(height: 16),
                      _buildFeatured(accent),
                    ]),
                  ),
                ),
                _products.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Text(
                            '该分类暂无可售商品',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : SliverToBoxAdapter(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 16.0;
                            final cols =
                                constraints.maxWidth > 640 ? 3 : 2;
                            final cardW =
                                (constraints.maxWidth - spacing * (cols - 1)) /
                                    cols;
                            final rows = <Widget>[];
                            for (var i = 0;
                                i < _products.length;
                                i += cols) {
                              final rowChildren = <Widget>[];
                              for (var j = i;
                                  j < i + cols && j < _products.length;
                                  j++) {
                                final card = _EntranceCard(
                                  animation: _enterController,
                                  delay: (j / _products.length) * 0.5,
                                  child: SizedBox(
                                    width: cardW,
                                    child: _ProductCard(
                                      product: _products[j],
                                      onTap: () => _onBuy(_products[j]),
                                    ),
                                  ),
                                );
                                rowChildren.add(Expanded(child: card));
                                if (j < i + cols - 1 &&
                                    j < _products.length - 1) {
                                  rowChildren.add(
                                    const SizedBox(width: spacing),
                                  );
                                }
                              }
                              rows.add(
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: rowChildren,
                                  ),
                                ),
                              );
                              if (i + cols < _products.length) {
                                rows.add(const SizedBox(height: spacing));
                              }
                            }
                            return Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 0, 24, 32),
                              child: Column(children: rows),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 页面品牌头：与首页一致的瑞士极简排版
  Widget _buildPageHeader() {
    final outline = context.colorScheme.outline;
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
          '会员商城',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.4,
            color: context.colorScheme.onSurfaceVariant.opacity60,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 1,
          color: outline.withValues(alpha: 0.12),
        ),
      ],
    );
  }

  Widget _buildHeader(Color accent) {
    final balanceAsync = ref.watch(phantomHomeProvider);
    return _EntranceCard(
      animation: _enterController,
      delay: 0,
      child: GlassSurface(
        padding: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.22),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withOpacity(0.55)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '会员商城',
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  balanceAsync.when(
                    data: (info) => Text(
                      info == null
                          ? '登录后查看余额与专属权益'
                          : '账户余额  ¥${(info.balance ?? 0).toStringAsFixed(2)}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 80,
                      height: 10,
                      child: const LinearProgressIndicator(),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: Text(
                'VIP 专享',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(Color accent) {
    final outline = context.colorScheme.outline;
    return _EntranceCard(
      animation: _enterController,
      delay: 0.08,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: MallCategory.values.map((c) {
            final selected = c == _category;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TapScale(
                onTap: () => setState(() => _category = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.14)
                        : context.colorScheme.surfaceContainer
                            .withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? accent.withValues(alpha: 0.45)
                          : outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    c.label,
                    style: TextStyle(
                      color: selected
                          ? accent
                          : context.colorScheme.onSurfaceVariant,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFeatured(Color accent) {
    return _EntranceCard(
      animation: _enterController,
      delay: 0.16,
      child: GlassSurface(
        padding: const EdgeInsets.all(22),
        borderRadius: BorderRadius.circular(24),
        blur: 20,
        tint: context.colorScheme.surfaceContainerHigh,
        tintOpacity: 0.55,
        borderOpacity: 0.8,
        boxShadow: const [],
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '限时特惠',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '年付 VIP 低至 ¥350',
                      style: TextStyle(
                        color: context.colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '高速节点 · 全球畅连 · 专属客服',
                      style: TextStyle(
                        color: context.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TapScale(
                onTap: () => _onBuy(_allProducts.firstWhere(
                  (p) => p.category == MallCategory.vip && p.price == 350,
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '立即抢购',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 错落入场：基于父级统一 AnimationController，按 delay 区间淡入上滑。
class _EntranceCard extends StatelessWidget {
  final Animation<double> animation;
  final double delay;
  final Widget child;

  const _EntranceCard({
    required this.animation,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Interval(delay, delay + 0.5, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(curve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

/// 商品卡片：玻璃质感 + 顶部渐变色带 + 图标徽章 + 价格 + 购买按钮。
class _ProductCard extends StatelessWidget {
  final MallProduct product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gradient = product.gradient;
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.last.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  product.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const Spacer(),
              if (product.tag != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: gradient.last.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.tag!,
                    style: TextStyle(
                      color: gradient.last,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            product.name,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            product.subtitle,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥',
                style: TextStyle(
                  color: gradient.last,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                product.price.toStringAsFixed(0),
                style: TextStyle(
                  color: gradient.last,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (product.originalPrice != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '¥${product.originalPrice!.toStringAsFixed(0)}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TapScale(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradient.last.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '立即购买',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 购买确认底部弹窗：玻璃质感 + 商品详情 + 渐变确认按钮。
class _PurchaseSheet extends StatelessWidget {
  final MallProduct product;

  const _PurchaseSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    final gradient = product.gradient;
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      tint: context.colorScheme.surfaceContainer,
      tintOpacity: 0.92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withOpacity(0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(product.icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            product.name,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.subtitle,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥',
                style: TextStyle(
                  color: gradient.last,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                product.price.toStringAsFixed(0),
                style: TextStyle(
                  color: gradient.last,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (product.originalPrice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 10),
                  child: Text(
                    '¥${product.originalPrice!.toStringAsFixed(0)}',
                    style: context.textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TapScale(
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  content: Text('已下单：${product.name}（演示）'),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient.last.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '确认购买',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum MallCategory { all, vip, traffic, node, topup }

extension MallCategoryExt on MallCategory {
  String get label => switch (this) {
        MallCategory.all => '全部',
        MallCategory.vip => '会员',
        MallCategory.traffic => '流量',
        MallCategory.node => '节点',
        MallCategory.topup => '充值',
      };
}

class MallProduct {
  final String name;
  final String subtitle;
  final MallCategory category;
  final double price;
  final double? originalPrice;
  final String? tag;
  final IconData icon;
  final List<Color> gradient;

  const MallProduct({
    required this.name,
    required this.subtitle,
    required this.category,
    required this.price,
    this.originalPrice,
    this.tag,
    required this.icon,
    required this.gradient,
  });
}

const List<MallProduct> _allProducts = [
  MallProduct(
    name: '月度 VIP',
    subtitle: '全节点高速畅连，尊享会员标识',
    category: MallCategory.vip,
    price: 30,
    originalPrice: 45,
    tag: '热门',
    icon: Icons.workspace_premium,
    gradient: [Color(0xFFF8E8C8), Color(0xFFD4AF37)],
  ),
  MallProduct(
    name: '年度 VIP',
    subtitle: '买一年省更多，平均每月不到 ¥30',
    category: MallCategory.vip,
    price: 350,
    originalPrice: 480,
    tag: '超值',
    icon: Icons.diamond_outlined,
    gradient: [Color(0xFFF6D89B), Color(0xFFC99A2E)],
  ),
  MallProduct(
    name: '100GB 流量包',
    subtitle: '7 天有效，随用随取',
    category: MallCategory.traffic,
    price: 15,
    originalPrice: 25,
    tag: '特惠',
    icon: Icons.cloud_outlined,
    gradient: [Color(0xFF00F7FF), Color(0xFF00BDE8)],
  ),
  MallProduct(
    name: '500GB 流量包',
    subtitle: '30 天有效，重度用户首选',
    category: MallCategory.traffic,
    price: 60,
    originalPrice: 98,
    icon: Icons.cloud_queue,
    gradient: [Color(0xFF33E1FF), Color(0xFF1FA8E0)],
  ),
  MallProduct(
    name: '1TB 流量包',
    subtitle: '90 天有效，海量不限速',
    category: MallCategory.traffic,
    price: 99,
    originalPrice: 158,
    tag: '限量',
    icon: Icons.storage_outlined,
    gradient: [Color(0xFF4DF0FF), Color(0xFF16B6E6)],
  ),
  MallProduct(
    name: '独享高速节点',
    subtitle: '专属 IP，极致稳定低延迟',
    category: MallCategory.node,
    price: 199,
    originalPrice: 299,
    tag: '独享',
    icon: Icons.bolt_outlined,
    gradient: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
  ),
  MallProduct(
    name: '专线游戏节点',
    subtitle: '电竞级低延迟，告别卡顿',
    category: MallCategory.node,
    price: 299,
    icon: Icons.sports_esports_outlined,
    gradient: [Color(0xFF9B5CFF), Color(0xFFC58CFF)],
  ),
  MallProduct(
    name: '充值 ¥50',
    subtitle: '到账 ¥55，多充多送',
    category: MallCategory.topup,
    price: 50,
    tag: '送5',
    icon: Icons.account_balance_wallet_outlined,
    gradient: [Color(0xFF00E676), Color(0xFF1DE9B6)],
  ),
  MallProduct(
    name: '充值 ¥200',
    subtitle: '到账 ¥230，超值回馈',
    category: MallCategory.topup,
    price: 200,
    tag: '送30',
    icon: Icons.wallet_outlined,
    gradient: [Color(0xFF2BFFA3), Color(0xFF13C9A0)],
  ),
];
