import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String mode;
  const ChatScreen({super.key, required this.mode});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller=TextEditingController();
  final _scrollController=ScrollController();
  final List<_ChatMessage> _messages=[
    const _ChatMessage(text:'Sannu! I am Mafix AI. What would you like help with today?',isUser:false),
  ];
  @override
  void dispose(){_controller.dispose();_scrollController.dispose();super.dispose();}

  void _send(){
    final text=_controller.text.trim();
    if(text.isEmpty)return;
    setState((){
      _messages.add(_ChatMessage(text:text,isUser:true));
      _messages.add(const _ChatMessage(
        text:'Your message is shown in this preview, but an AI provider is not connected yet. In the next setup step, we will connect the assistant securely.',
        isUser:false));
      _controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(_scrollController.hasClients){
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration:const Duration(milliseconds:250),curve:Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(widget.mode,style:const TextStyle(fontWeight:FontWeight.w700)),
      const Text('Mafix AI • Preview',style:TextStyle(fontSize:11,color:Colors.white54)),
    ])),
    body:SafeArea(child:Column(children:[
      Expanded(child:ListView.builder(controller:_scrollController,padding:const EdgeInsets.all(16),
        itemCount:_messages.length,itemBuilder:(context,index){
          final m=_messages[index];
          return Align(alignment:m.isUser?Alignment.centerRight:Alignment.centerLeft,
            child:Container(constraints:BoxConstraints(maxWidth:MediaQuery.of(context).size.width*.82),
              margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.symmetric(horizontal:15,vertical:12),
              decoration:BoxDecoration(color:m.isUser?const Color(0xFF5148D8):const Color(0xFF171D42),borderRadius:BorderRadius.circular(18)),
              child:Text(m.text,style:const TextStyle(height:1.4))));
        })),
      Padding(padding:const EdgeInsets.fromLTRB(12,8,12,12),child:Row(children:[
        Expanded(child:TextField(controller:_controller,minLines:1,maxLines:5,textInputAction:TextInputAction.send,
          onSubmitted:(_)=>_send(),decoration:const InputDecoration(hintText:'Message Mafix AI...',contentPadding:EdgeInsets.symmetric(horizontal:16,vertical:14)))),
        const SizedBox(width:8),
        IconButton.filled(onPressed:_send,icon:const Icon(Icons.arrow_upward),
          style:IconButton.styleFrom(backgroundColor:const Color(0xFF6C63FF),foregroundColor:Colors.white,minimumSize:const Size(50,50))),
      ])),
    ])),
  );
}
class _ChatMessage {
  final String text; final bool isUser;
  const _ChatMessage({required this.text,required this.isUser});
}
