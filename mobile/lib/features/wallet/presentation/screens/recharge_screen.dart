import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});
  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  List<CoinPackage> _packages = [];
  bool _loading = true;
  bool _purchasing = false;
  late Razorpay _razorpay;
  int _purchasedCoins = 0;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      final resp = await api.get(ApiEndpoints.coinPackages);
      final list = (resp.data['data'] as List<dynamic>?) ?? [];
      setState(() {
        _packages = list.map((j) => CoinPackage.fromJson(j)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _purchase(CoinPackage pkg) async {
    if (_purchasing) return;
    setState(() => _purchasing = true);
    try {
      final resp = await api.post(ApiEndpoints.createOrder, data: {'coinPackageId': pkg.id});
      final data = resp.data['data'];
      _purchasedCoins = pkg.totalCoins;
      _razorpay.open({
        'key': const String.fromEnvironment('RAZORPAY_KEY', defaultValue: 'rzp_test_xxx'),
        'amount': data['amount'],
        'currency': 'INR',
        'name': 'Milan',
        'description': '${pkg.totalCoins} Coins',
        'order_id': data['orderId'],
        'prefill': {'contact': '', 'email': ''},
        'theme': {'color': '#FF4D8B'},
        'external': {'wallets': ['paytm']},
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create order'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  void _onSuccess(PaymentSuccessResponse response) async {
    try {
      await api.post(ApiEndpoints.verifyPayment, data: {
        'razorpayOrderId': response.orderId,
        'razorpayPaymentId': response.paymentId,
        'razorpaySignature': response.signature,
      });
      walletProvider.addCoins(_purchasedCoins.toDouble());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coins added successfully!'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (_) {
      walletProvider.fetchBalance(force: true);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Payment Received'),
            content: const Text('Payment was received but coin credit failed. Please contact support with your payment ID.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  void _onError(PaymentFailureResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}'), backgroundColor: AppColors.error),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Buy Coins'),
        actions: [
          // Coin balance chip in appbar
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppColors.pinkPurpleGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                ListenableBuilder(
                  listenable: walletProvider,
                  builder: (_, __) => Text(
                    walletProvider.balance.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // Promo Banner
                SliverToBoxAdapter(child: _PromoBanner(packages: _packages)),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Section title
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Choose a Pack',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // 3-column grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.76,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _PackageCard(
                        package: _packages[i],
                        onTap: () => _purchase(_packages[i]),
                      ),
                      childCount: _packages.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Footer
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('10 🪙  =  1 💎', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Learn more about Diamonds',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Promo Banner ──────────────────────────────────────────────────────────────
class _PromoBanner extends StatelessWidget {
  final List<CoinPackage> packages;
  const _PromoBanner({required this.packages});

  @override
  Widget build(BuildContext context) {
    // Find highest discount package
    CoinPackage? promo;
    for (final p in packages) {
      if (p.hasDiscount && (promo == null || p.discountAmount > promo.discountAmount)) {
        promo = p;
      }
    }
    if (promo == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 88,
      decoration: BoxDecoration(
        gradient: AppColors.bannerGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Flat ₹${promo.discountAmount} off',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${promo.coins} coins @ ',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '₹${promo.originalPriceInr!.toStringAsFixed(0)} ',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.white54,
                      ),
                    ),
                    Text(
                      '₹${promo.priceInr.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    const Text('▶', style: TextStyle(color: Colors.white60, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          // Decorative emoji on right
          const Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(child: Text('🏯🎌', style: TextStyle(fontSize: 32))),
          ),
          // Dot indicator
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 16, height: 3, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Container(width: 5, height: 3, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Package Card ──────────────────────────────────────────────────────────────
class _PackageCard extends StatelessWidget {
  final CoinPackage package;
  final VoidCallback onTap;
  const _PackageCard({required this.package, required this.onTap});

  String _coinEmoji(int coins) {
    if (coins >= 10000) return '💰';
    if (coins >= 5000) return '🧿';
    if (coins >= 1000) return '🪣';
    return '🪙';
  }

  @override
  Widget build(BuildContext context) {
    final badge = package.badge;
    final isHot = badge?.toLowerCase() == 'hot';
    final isValue = badge?.toLowerCase() == 'value pack';

    // Border gradient for highlighted packages
    final hasBadge = badge != null && badge.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHot
                ? AppColors.pink.withValues(alpha: 0.5)
                : isValue
                    ? AppColors.purple.withValues(alpha: 0.5)
                    : AppColors.divider,
            width: hasBadge ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isHot
                  ? AppColors.pink.withValues(alpha: 0.08)
                  : isValue
                      ? AppColors.purple.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge
            if (badge != null && badge.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: isHot ? AppColors.pinkPurpleGradient : AppColors.callBtnGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHot) const Text('🔥 ', style: TextStyle(fontSize: 9)),
                    if (isValue) const Text('⭐ ', style: TextStyle(fontSize: 9)),
                    Text(
                      badge,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ] else
              const SizedBox(height: 4),

            // Coin emoji
            Text(_coinEmoji(package.coins), style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 4),

            // Coin count
            Text(
              _fmt(package.coins),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),

            // Bonus coins
            if (package.bonusCoins > 0) ...[
              const SizedBox(height: 2),
              ShaderMask(
                shaderCallback: (b) => AppColors.pinkPurpleGradient.createShader(b),
                child: Text(
                  '+${_fmt(package.bonusCoins)} 🪙',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Original price (strikethrough)
            if (package.hasDiscount)
              Text(
                '₹${package.originalPriceInr!.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 10,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.textHint,
                ),
              ),

            // Price button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppColors.pinkPurpleGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '₹${package.priceInr.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),

            // Discount label
            if (package.hasDiscount) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Flat ₹${package.discountAmount} off',
                  style: const TextStyle(color: AppColors.purple, fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return '$n';
  }
}
