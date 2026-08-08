import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// 生命粒子球 V5 · 3D透视投影 + 双控制器(呼吸4s + 旋转30s)
/// 粒子在球体内随机分布·透视投影(z→大小+透明度)·近大远小
/// 多层光晕弥散·NASA深空/哈勃星云/神经元胞体美学
/// 不是发光圆圈·不是赛博朋克
///
/// 状态: idle(缓慢呼吸) / listening(录音·粒子跳动·冰蓝) / speaking(AI回复·金脉冲波) / thinking(内部凝聚旋转·紫涡)

// ==========================================
// 3D粒子数据
// ==========================================
class _Particle3D {
  double x, y, z;       // 球体内3D坐标 (-1..1)
  double baseSize;       // 基础大小
  double colorMix;       // 0=暖金 1=银灰
  double twinklePhase;   // 闪烁相位
  _Particle3D(this.x, this.y, this.z, this.baseSize, this.colorMix, this.twinklePhase);
}

// ==========================================
// 主Widget (保持接口不变)
// ==========================================
class SymbioOrb extends StatefulWidget {
  final double size;
  final String status;       // 'online' | 'sleeping' | 'thinking'
  final String voiceState;   // 'idle' | 'listening' | 'speaking'
  final VoidCallback? onTap;

  const SymbioOrb({
    super.key,
    this.size = 200,
    this.status = 'online',
    this.voiceState = 'idle',
    this.onTap,
  });

  @override
  State<SymbioOrb> createState() => SymbioOrbState();
}

class SymbioOrbState extends State<SymbioOrb> with TickerProviderStateMixin {
  late AnimationController _breatheCtrl;  // 4秒呼吸
  late AnimationController _rotateCtrl;   // 30秒旋转

  double _touchScale = 1.0;
  double _touchX = 0, _touchY = 0;
  double _touchVX = 0, _touchVY = 0;
  bool _touched = false;
  double _voiceEnergy = 0.0;
  final _start = DateTime.now().millisecondsSinceEpoch;
  double _elapsed = 0;

  final _particles = <_Particle3D>[];

  @override
  void initState() {
    super.initState();

    // 呼吸周期: 4秒 (3-5秒范围)
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )
      ..repeat()
      ..addListener((){
        _elapsed = (DateTime.now().millisecondsSinceEpoch - _start) / 1000.0;
        if(!_touched){
          _touchX *= 0.95;
          _touchY *= 0.95;
          if(_touchX.abs()<0.001 && _touchY.abs()<0.001){_touchX=0;_touchY=0;}
        }
        setState((){});
      });

    // 球体旋转: 30秒一圈
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _initParticles();
  }

  void _initParticles() {
    final rng = Random(42);
    _particles.clear();

    for (int i = 0; i < 300; i++) {
      // 球体内随机分布(拒绝采样保证均匀)
      double x, y, z;
      do {
        x = rng.nextDouble() * 2 - 1;
        y = rng.nextDouble() * 2 - 1;
        z = rng.nextDouble() * 2 - 1;
      } while (x * x + y * y + z * z > 1.0);

      _particles.add(_Particle3D(
        x, y, z,
        0.4 + rng.nextDouble() * 2.8,           // 基础大小
        rng.nextDouble(),                         // 金/银混合比
        rng.nextDouble() * pi * 2,               // 闪烁相位
      ));
    }
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  Color _glowColor() {
    switch (widget.voiceState) {
      case 'listening':
        return const Color(0xFF60d0e8);
      case 'speaking':
        return HermesTheme.gold;
      default:
        break;
    }
    switch (widget.status) {
      case 'thinking':
        return const Color(0xFFa080e0);
      case 'sleeping':
        return const Color(0xFF6b6b7a);
      default:
        return HermesTheme.gold;
    }
  }

  void setVoiceEnergy(double e) {
    if (mounted) setState(() => _voiceEnergy = e.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final glow = _glowColor();

    return GestureDetector(
      onTap: () {
        setState(() => _touchScale = 1.12);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) setState(() => _touchScale = 1.0);
        });
        widget.onTap?.call();
      },
      onPanUpdate: (d) {
        setState(() {
          _touched = true;
          _touchX += d.delta.dx / widget.size * 0.8;
          _touchY += d.delta.dy / widget.size * 0.8;
          _touchVX = d.delta.dx / widget.size;
          _touchVY = d.delta.dy / widget.size;
        });
      },
      onPanEnd: (_) {
        _touched = false;
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _OrbPainter3D(
            particles: _particles,
            glowColor: glow,
            scale: _touchScale,
            breatheCtrl: _breatheCtrl,
            rotateCtrl: _rotateCtrl,
            status: widget.status,
            voiceState: widget.voiceState,
            voiceEnergy: _voiceEnergy,
            touchX: _touchX,
            touchY: _touchY,
            touchVX: _touchVX,
            touchVY: _touchVY,
            touched: _touched,
            elapsed: _elapsed,
          ),
          size: Size(widget.size, widget.size),
        ),
      ),
    );
  }
}

// ==========================================
// 3D透视投影绘制器
// ==========================================
class _OrbPainter3D extends CustomPainter {
  final List<_Particle3D> particles;
  final Color glowColor;
  final double scale, voiceEnergy, touchX, touchY, touchVX, touchVY, elapsed;
  final String status, voiceState;
  final bool touched;
  final AnimationController breatheCtrl;
  final AnimationController rotateCtrl;

  _OrbPainter3D({
    required this.particles,
    required this.glowColor,
    required this.scale,
    required this.breatheCtrl,
    required this.rotateCtrl,
    required this.status,
    required this.voiceState,
    this.voiceEnergy = 0,
    this.touchX = 0,
    this.touchY = 0,
    this.touchVX = 0,
    this.touchVY = 0,
    this.touched = false,
    this.elapsed = 0,
  }) : super(repaint: Listenable.merge([breatheCtrl, rotateCtrl]));

  /// Y轴旋转矩阵
  void _rotateY(double x, double y, double z, double angle, List<double> out) {
    final cosA = cos(angle), sinA = sin(angle);
    out[0] = x * cosA + z * sinA;
    out[1] = y;
    out[2] = -x * sinA + z * cosA;
  }

  /// X轴微倾矩阵 (叠加在Y旋转之后)
  void _rotateX(double x, double y, double z, double angle, List<double> out) {
    final cosA = cos(angle), sinA = sin(angle);
    out[0] = x;
    out[1] = y * cosA - z * sinA;
    out[2] = y * sinA + z * cosA;
  }

  /// 透视投影: z越近→位置越偏离中心·粒子越大·越不透明
  void _project(double x, double y, double z, double cx, double cy, double radius,
      List<double> out) {
    const perspective = 3.0;
    final depth = perspective + z;             // z∈[-1,1] → depth∈[2,4]
    out[0] = cx + x * radius / depth;
    out[1] = cy + y * radius / depth;
    out[2] = depth;                            // 用于大小/透明度计算
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 使用elapsed无缝连续·不用controller.value(会跳)
    final breatheVal = elapsed / 4.0;            // 4秒呼吸周期
    final rotateVal = elapsed / 30.0;            // 30秒旋转

    final cx = size.width / 2 + touchX * size.width * 0.25;
    final cy = size.height / 2 + touchY * size.height * 0.25;
    final baseR = min(size.width, size.height) * 0.7 * scale;

    final isListening = voiceState == 'listening';
    final isSpeaking = voiceState == 'speaking';
    final isThinking = status == 'thinking';

    // --- 4秒呼吸(±10%) ---
    final breathe = 1.0 + 0.1 * sin(breatheVal * pi * 2);
    final radius = baseR * breathe;

    // --- 自转角度 ---
    final rotY = rotateVal * pi * 2;            // 30秒一圈(Y轴)
    const rotX = 0.35;                          // 微倾角

    // --- 语音能量影响 ---
    final voiceBounce = isListening ? voiceEnergy * 0.2 : 0.0;

    // ==========================================
    // 外层弥散星云光晕 (NASA深空·多层)
    // ==========================================
    // 最外层: 极淡·大范围
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 4.0 * breathe,
      Paint()
        ..shader = RadialGradient(colors: [
          glowColor.withAlpha(isSpeaking ? 8 : 4),
          glowColor.withAlpha(2),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(
          center: Offset(cx, cy),
          radius: radius * 4.0,
        )),
    );

    // 第2层: 中范围弥散
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 2.5 * breathe,
      Paint()
        ..shader = RadialGradient(colors: [
          glowColor.withAlpha(isSpeaking ? 14 : isListening ? 8 : 6),
          glowColor.withAlpha(3),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(
          center: Offset(cx, cy),
          radius: radius * 2.5,
        )),
    );

    // 第3层: 内层光晕
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 1.6 * breathe,
      Paint()
        ..shader = RadialGradient(colors: [
          glowColor.withAlpha(isListening ? 25 : isSpeaking ? 30 : 16),
          glowColor.withAlpha(6),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(
          center: Offset(cx, cy),
          radius: radius * 1.6,
        )),
    );

    // ==========================================
    // 3D粒子渲染 (按z排序·远先近后)
    // ==========================================
    final projected = <_ProjParticle>[];
    final rotYOut = List<double>.filled(3, 0);
    final rotXOut = List<double>.filled(3, 0);
    final projOut = List<double>.filled(3, 0);

    for (final p in particles) {
      // Y旋转
      _rotateY(p.x, p.y, p.z, rotY, rotYOut);
      // X微倾
      _rotateX(rotYOut[0], rotYOut[1], rotYOut[2], rotX, rotXOut);
      // 透视投影
      _project(rotXOut[0], rotXOut[1], rotXOut[2], cx, cy,
          radius * (1.0 + voiceBounce), projOut);

      // z深度 → 大小系数(近大远小)
      final depthFactor = (4.0 - projOut[2]) / 2.0; // z近→depth小→factor大

      // 闪烁效果
      final twinkle = 0.6 + 0.4 * sin(breatheVal * pi * 2 * 3.5 + p.twinklePhase);

      projected.add(_ProjParticle(
        x: projOut[0],
        y: projOut[1],
        depth: projOut[2],
        size: p.baseSize * depthFactor * (touched ? 1.3 : 1.0) * twinkle,
        alpha: (depthFactor * twinkle).clamp(0.12, 1.0),
        colorMix: p.colorMix,
      ));
    }

    // 按深度排序(远的先画)
    projected.sort((a, b) => b.depth.compareTo(a.depth));

    // 暖金和银灰色定义
    const goldColor = Color(0xFFD4A853);
    const silverColor = Color(0xFFC0C0C0);

    for (final pp in projected) {
      final mix = pp.colorMix;
      final particleColor = Color.lerp(goldColor, silverColor, mix)!;
      final alpha = pp.alpha.clamp(0.0, 1.0);

      // 粒子主体
      canvas.drawCircle(
        Offset(pp.x, pp.y),
        pp.size,
        Paint()..color = particleColor.withAlpha((alpha * 210).toInt()),
      );

      // 粒子光晕(较大粒子才有)
      if (pp.size > 0.7) {
        canvas.drawCircle(
          Offset(pp.x, pp.y),
          pp.size * 2.8,
          Paint()
            ..shader = RadialGradient(colors: [
              particleColor.withAlpha((alpha * 35).toInt()),
              Colors.transparent,
            ]).createShader(Rect.fromCircle(
              center: Offset(pp.x, pp.y),
              radius: pp.size * 2.8,
            )),
        );
      }
    }

    // ==========================================
    // AI回复脉冲波 (speaking)
    // ==========================================
    if (isSpeaking) {
      for (int w = 0; w < 3; w++) {
        final phase = ((breatheVal * 2.5 + w * 0.33) % 1.0);
        final pulseR = radius * (0.3 + phase * 2.5);
        final pulseAlpha = ((1.0 - phase) * 50).toInt();
        canvas.drawCircle(
          Offset(cx, cy),
          pulseR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0 + (1.0 - phase) * 0.8
            ..color = glowColor.withAlpha(pulseAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    // ==========================================
    // 思考态·内部涡旋
    // ==========================================
    if (isThinking) {
      for (int i = 0; i < 7; i++) {
        final a = i * pi * 2 / 7 + breatheVal * 3.5;
        final dist = radius * 0.22;
        final px = cx + cos(a) * dist;
        final py = cy + sin(a) * dist;
        canvas.drawCircle(
          Offset(px, py),
          1.8,
          Paint()..color = glowColor.withAlpha(130),
        );
        canvas.drawLine(
          Offset(px, py),
          Offset(cx + cos(a) * dist * 3.0, cy + sin(a) * dist * 3.0),
          Paint()
            ..color = glowColor.withAlpha(25)
            ..strokeWidth = 0.8,
        );
      }
    }

    // ==========================================
    // 内层光核(白金色·暖)
    // ==========================================
    final coreAlpha = isSpeaking ? 190 : isListening ? 150 : isThinking ? 170 : 210;
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.36 * breathe,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withAlpha(coreAlpha),
          glowColor.withAlpha(70),
          glowColor.withAlpha(0),
        ]).createShader(Rect.fromCircle(
          center: Offset(cx, cy),
          radius: radius * 0.42,
        )),
    );

    // ==========================================
    // 触摸涟漪
    // ==========================================
    if (touched) {
      final rippleR = radius * 1.5 * (0.4 + 0.6 * sin(breatheVal * 4.0));
      canvas.drawCircle(
        Offset(cx, cy),
        rippleR,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.transparent,
            glowColor.withAlpha(30),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(
            center: Offset(cx, cy),
            radius: rippleR,
          )),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter3D old) => true;
}

/// 投影后的粒子(用于排序)
class _ProjParticle {
  final double x, y, depth, size, alpha, colorMix;
  _ProjParticle({
    required this.x,
    required this.y,
    required this.depth,
    required this.size,
    required this.alpha,
    required this.colorMix,
  });
}
