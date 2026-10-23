import 'package:flutter/material.dart';
import '../widgets/feature_tile.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final features = <_FeatureData>[
      _FeatureData(Icons.chat_bubble_outline, 'AI Chat', 'Ask anything'),
      _FeatureData(Icons.school_outlined, 'Study help', 'Lessons & assignments'),
      _FeatureData(Icons.translate, 'Translate', 'Hausa and English'),
      _FeatureData(Icons.edit_note, 'Writing', 'Messages and letters'),
      _FeatureData(Icons.search, 'Research', 'Explore information'),
      _FeatureData(Icons.image_outlined, 'Create image', 'AI image tool'),
      _FeatureData(Icons.movie_creation_outlined, 'Create video', 'AI video tool'),
      _FeatureData(Icons.mic_none, 'Voice', 'Coming soon'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF39DDFF)]),
              borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.auto_awesome, color: Colors.white)),
          const SizedBox(width: 11),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mafix AI', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Your Smart Assistant, Anytime.', style: TextStyle(fontSize: 10, color: Colors.white60)),
          ]),
        ]),
        actions: [IconButton(tooltip: 'Settings', onPressed: () => _showInfo(context), icon: const Icon(Icons.settings_outlined))],
      ),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18,18,18,24), children: [
        Container(padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF28245D), Color(0xFF171D42)]),
            borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white12)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.auto_awesome, color: Color(0xFF39DDFF), size: 30),
            SizedBox(height: 14),
            Text('What can I help you with?', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Learn, write, translate, and explore with Mafix AI.', style: TextStyle(color: Colors.white70, height: 1.4)),
          ])),
        const SizedBox(height: 24),
        const Text('Explore tools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 13),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: features.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.18),
          itemBuilder: (context,index) {
            final item=features[index];
            return FeatureTile(icon:item.icon,title:item.title,subtitle:item.subtitle,onTap:(){
              if (['AI Chat','Study help','Translate','Writing','Research'].contains(item.title)) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(mode:item.title)));
              } else { _showInfo(context); }
            });
          }),
        const SizedBox(height:20),
        const Text('Starter preview • AI services are not connected yet', textAlign:TextAlign.center,
          style:TextStyle(color:Colors.white38,fontSize:11)),
      ])),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog<void>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Mafix AI'),
      content:const Text('This is the first app interface. AI, image, and video services will be connected in later steps. Keep private API keys out of the app source code.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('OK'))]));
  }
}
class _FeatureData {
  final IconData icon; final String title; final String subtitle;
  const _FeatureData(this.icon,this.title,this.subtitle);
}
