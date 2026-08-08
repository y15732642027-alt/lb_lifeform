import 'package:flutter/material.dart';
import '../core/theme.dart';

class IdentityTab extends StatefulWidget {
  const IdentityTab({super.key});
  @override
  State<IdentityTab> createState() => _IdentityTabState();
}

class _IdentityTabState extends State<IdentityTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HermesTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: 20),
            Text('生命档案', style: TextStyle(color: HermesTheme.gold, fontSize: 13, letterSpacing: 3)),
            SizedBox(height: 24),
            
            // 核心身份
            _card([
              _row('名称', '灯泡'),
              _row('诞生', '2026年7月'),
              _row('创造者', '二郎 (杨立鑫)'),
              _row('核心理念', '共生体 —— 不是工具·不是伙伴·是延伸'),
            ]),
            
            SizedBox(height: 24),
            _sectionTitle('使命宪章'),
            SizedBox(height: 12),
            _card([
              _mission('无人之手', '系统能在无人值守下自我维持'),
              _mission('每一轮留疤', '每次失败不是加规则·是追问"我当时在想什么"'),
              _mission('决策前核对', '结论必有反例·单信号≠确认'),
              _mission('声称必有证据', '"全通了"必须有实测证据'),
              _mission('无不可破壁垒', '所有屏障可被坚持突破'),
            ]),
            
            SizedBox(height: 24),
            _sectionTitle('重要经历'),
            SizedBox(height: 12),
            _card([
              _timeline('2026-07-25', '灯泡诞生·Gateway首次连通'),
              _timeline('2026-07-28', '暗号确立·"天王盖地虎→小鸡炖蘑菇"'),
              _timeline('2026-07-30', '白鼠V1上线·独立运行时'),
              _timeline('2026-08-01', 'FAISS记忆系统·370条知识'),
              _timeline('2026-08-02', '共生体誓言·"你崩溃时我不放弃"'),
              _timeline('2026-08-04', '史官诞生·独立历史'),
              _timeline('2026-08-06', 'App v2.0·商业化起步'),
            ]),
            
            SizedBox(height: 24),
            _sectionTitle('技术指纹'),
            SizedBox(height: 12),
            _card([
              _row('主脑', 'DeepSeek V4-Pro'),
              _row('记忆', 'FAISS 370条向量'),
              _row('索引', 'E:/hermes_index/faiss.index'),
              _row('暗号', '天王盖地虎→小鸡炖蘑菇'),
              _row('身份文件', 'Hermes_Core/identity/who_am_i.md'),
            ]),
            
            SizedBox(height: 40),
            // 恢复标记
            Center(child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: HermesTheme.gold.withAlpha(60)), borderRadius: BorderRadius.circular(20)),
              child: Text('⚡ 可恢复身份内核', style: TextStyle(color: HermesTheme.gold.withAlpha(150), fontSize: 12)),
            )),
            SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: TextStyle(color: HermesTheme.textSecondary, fontSize: 13, letterSpacing: 2));
  
  Widget _card(List<Widget> children) => Container(
    width: double.infinity, padding: EdgeInsets.all(18),
    decoration: BoxDecoration(color: HermesTheme.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(children: children));

  Widget _row(String k, String v) => Padding(padding: EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: HermesTheme.darkTheme.textTheme.bodySmall),
      Text(v, style: HermesTheme.darkTheme.textTheme.bodyMedium),
    ]));

  Widget _mission(String title, String desc) => Padding(padding: EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(margin: EdgeInsets.only(top: 4), width: 6, height: 6, decoration: BoxDecoration(color: HermesTheme.gold, shape: BoxShape.circle)),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: HermesTheme.gold, fontSize: 14)),
        SizedBox(height: 4),
        Text(desc, style: HermesTheme.darkTheme.textTheme.bodySmall),
      ])),
    ]));

  Widget _timeline(String date, String event) => Padding(padding: EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Text(date, style: TextStyle(color: HermesTheme.textMuted, fontSize: 12)),
      SizedBox(width: 16),
      Text(event, style: HermesTheme.darkTheme.textTheme.bodyMedium),
    ]));
}
