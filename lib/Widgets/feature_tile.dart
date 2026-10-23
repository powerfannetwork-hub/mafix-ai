import 'package:flutter/material.dart';

class FeatureTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  const FeatureTile({super.key,required this.icon,required this.title,required this.subtitle,required this.onTap});
  @override
  Widget build(BuildContext context)=>Material(
    color:const Color(0xFF171D42),borderRadius:BorderRadius.circular(20),
    child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(20),
      child:Container(padding:const EdgeInsets.all(15),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white10)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
          Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFF6C63FF).withOpacity(.20),borderRadius:BorderRadius.circular(14)),
            child:Icon(icon,color:const Color(0xFF8E88FF))),
          const SizedBox(height:12),
          Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),
          const SizedBox(height:4),
          Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white54,fontSize:11)),
        ]))));
}
