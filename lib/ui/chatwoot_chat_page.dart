import 'dart:io';

import 'package:chatwoot_sdk/chatwoot_callbacks.dart';
import 'package:chatwoot_sdk/chatwoot_client.dart';
import 'package:chatwoot_sdk/data/local/entity/chatwoot_message.dart';
import 'package:chatwoot_sdk/data/local/entity/chatwoot_user.dart';
import 'package:chatwoot_sdk/data/remote/chatwoot_client_exception.dart';
import 'package:chatwoot_sdk/ui/chatwoot_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

///Chatwoot chat widget
/// {@category FlutterClientSdk}
class ChatwootChat extends StatefulWidget {
  /// Specifies a custom app bar for chatwoot page widget
  final PreferredSizeWidget? appBar;

  ///Installation url for chatwoot
  final String baseUrl;

  ///Identifier for target chatwoot inbox.
  ///
  /// For more details see https://www.chatwoot.com/docs/product/channels/api/client-apis
  final String inboxIdentifier;

  /// Enables persistence of chatwoot client instance's contact, conversation and messages to disk
  /// for convenience.
  ///
  /// Setting [enablePersistence] to false holds chatwoot client instance's data in memory and is cleared as
  /// soon as chatwoot client instance is disposed
  final bool enablePersistence;

  /// Custom user details to be attached to chatwoot contact
  final ChatwootUser? user;

  /// See [ChatList.onEndReached]
  final Future<void> Function()? onEndReached;

  /// See [ChatList.onEndReachedThreshold]
  final double? onEndReachedThreshold;

  /// See [Message.onMessageLongPress]
  final void Function(BuildContext context, types.Message)? onMessageLongPress;

  /// See [Message.onMessageTap]
  final void Function(types.Message)? onMessageTap;

  /// See [Input.onSendPressed]
  final void Function(types.PartialText)? onSendPressed;

  /// See [Input.onTextChanged]
  final void Function(String)? onTextChanged;

  /// Show avatars for received messages.
  final bool showUserAvatars;

  /// Show user names for received messages.
  final bool showUserNames;

  // final ChatwootChatTheme? theme;

  /// See [ChatwootL10n]
  final ChatwootL10n l10n;

  /// See [Chat.timeFormat]
  final DateFormat? timeFormat;

  /// See [Chat.dateFormat]
  final DateFormat? dateFormat;

  ///See [ChatwootCallbacks.onWelcome]
  final void Function()? onWelcome;

  ///See [ChatwootCallbacks.onPing]
  final void Function()? onPing;

  ///See [ChatwootCallbacks.onConfirmedSubscription]
  final void Function()? onConfirmedSubscription;

  ///See [ChatwootCallbacks.onConversationStartedTyping]
  final void Function()? onConversationStartedTyping;

  ///See [ChatwootCallbacks.onConversationIsOnline]
  final void Function()? onConversationIsOnline;

  ///See [ChatwootCallbacks.onConversationIsOffline]
  final void Function()? onConversationIsOffline;

  ///See [ChatwootCallbacks.onConversationStoppedTyping]
  final void Function()? onConversationStoppedTyping;

  ///See [ChatwootCallbacks.onMessageReceived]
  final void Function(ChatwootMessage)? onMessageReceived;

  ///See [ChatwootCallbacks.onMessageSent]
  final void Function(ChatwootMessage)? onMessageSent;

  ///See [ChatwootCallbacks.onMessageDelivered]
  final void Function(ChatwootMessage)? onMessageDelivered;

  ///See [ChatwootCallbacks.onMessageUpdated]
  final void Function(ChatwootMessage)? onMessageUpdated;

  ///See [ChatwootCallbacks.onPersistedMessagesRetrieved]
  final void Function(List<ChatwootMessage>)? onPersistedMessagesRetrieved;

  ///See [ChatwootCallbacks.onMessagesRetrieved]
  final void Function(List<ChatwootMessage>)? onMessagesRetrieved;

  ///See [ChatwootCallbacks.onError]
  final void Function(ChatwootClientException)? onError;

  ///Horizontal padding is reduced if set to true
  final bool isPresentedInDialog;

  // final void Function()? onAttachmentPressed;

  const ChatwootChat(
      {Key? key,
      required this.baseUrl,
      required this.inboxIdentifier,
      this.enablePersistence = true,
      this.user,
      this.appBar,
      this.onEndReached,
      this.onEndReachedThreshold,
      this.onMessageLongPress,
      this.onMessageTap,
      this.onSendPressed,
      this.onTextChanged,
      this.showUserAvatars = true,
      this.showUserNames = true,
      // this.theme,
      this.l10n = const ChatwootL10n(),
      this.timeFormat,
      this.dateFormat,
      this.onWelcome,
      this.onPing,
      this.onConfirmedSubscription,
      this.onMessageReceived,
      this.onMessageSent,
      this.onMessageDelivered,
      this.onMessageUpdated,
      this.onPersistedMessagesRetrieved,
      this.onMessagesRetrieved,
      this.onConversationStartedTyping,
      this.onConversationStoppedTyping,
      this.onConversationIsOnline,
      this.onConversationIsOffline,
      this.onError,
      this.isPresentedInDialog = false})
      : super(key: key);

  @override
  _ChatwootChatState createState() => _ChatwootChatState();
}

class _ChatwootChatState extends State<ChatwootChat> {
  ///
  List<types.Message> _messages = [];

  late String status;

  final idGen = Uuid();
  late types.User _user;
  ChatwootClient? chatwootClient;

  @override
  void initState() {
    super.initState();

    if (widget.user == null) {
      _user = types.User(id: idGen.v4());
    } else {
      _user = types.User(
        id: widget.user?.identifier ?? idGen.v4(),
        firstName: widget.user?.name,
        imageUrl: widget.user?.avatarUrl,
      );
    }

    final chatwootCallbacks = ChatwootCallbacks(
      onWelcome: () {
        widget.onWelcome?.call();
      },
      onPing: () {
        widget.onPing?.call();
      },
      onConfirmedSubscription: () {
        widget.onConfirmedSubscription?.call();
      },
      onConversationStartedTyping: () {
        widget.onConversationStoppedTyping?.call();
      },
      onConversationStoppedTyping: () {
        widget.onConversationStartedTyping?.call();
      },
      onPersistedMessagesRetrieved: (persistedMessages) {
        if (widget.enablePersistence) {
          setState(() {
            _messages =
                persistedMessages.map((message) => _chatwootMessageToTextMessage(message)).toList();
          });
        }
        widget.onPersistedMessagesRetrieved?.call(persistedMessages);
      },
      onMessagesRetrieved: (messages) {
        if (messages.isEmpty) {
          return;
        }
        setState(() {
          final chatMessages =
              messages.map((message) => _chatwootMessageToTextMessage(message)).toList();
          final mergedMessages = <types.Message>[..._messages, ...chatMessages].toSet().toList();
          final now = DateTime.now().millisecondsSinceEpoch;
          mergedMessages.sort((a, b) {
            return (b.createdAt ?? now).compareTo(a.createdAt ?? now);
          });
          _messages = mergedMessages;
        });
        widget.onMessagesRetrieved?.call(messages);
      },
      onMessageReceived: (chatwootMessage) {
        _addMessage(_chatwootMessageToTextMessage(chatwootMessage));
        widget.onMessageReceived?.call(chatwootMessage);
      },
      onMessageDelivered: (chatwootMessage, echoId) {
        _handleMessageSent(_chatwootMessageToTextMessage(chatwootMessage, echoId: echoId));
        widget.onMessageDelivered?.call(chatwootMessage);
      },
      onMessageUpdated: (chatwootMessage) {
        _handleMessageUpdated(
            _chatwootMessageToTextMessage(chatwootMessage, echoId: chatwootMessage.id.toString()));
        widget.onMessageUpdated?.call(chatwootMessage);
      },
      onMessageSent: (chatwootMessage, echoId) {
        final textMessage = types.TextMessage(
            id: echoId,
            author: _user,
            text: chatwootMessage.content ?? "",
            status: types.Status.delivered);
        _handleMessageSent(textMessage);
        widget.onMessageSent?.call(chatwootMessage);
      },
      onConversationResolved: () {
        final resolvedMessage = types.TextMessage(
            id: idGen.v4(),
            text: widget.l10n.conversationResolvedMessage,
            author: types.User(
                id: idGen.v4(),
                firstName: "Bot",
                imageUrl:
                    "https://d2cbg94ubxgsnp.cloudfront.net/Pictures/480x270//9/9/3/512993_shutterstock_715962319converted_920340.png"),
            status: types.Status.delivered);
        _addMessage(resolvedMessage);
      },
      onError: (error) {
        if (error.type == ChatwootClientExceptionType.SEND_MESSAGE_FAILED) {
          _handleSendMessageFailed(error.data);
        }
        print("Ooops! Something went wrong. Error Cause: ${error.cause}");
        widget.onError?.call(error);
      },
    );

    ChatwootClient.create(
            baseUrl: widget.baseUrl,
            inboxIdentifier: widget.inboxIdentifier,
            user: widget.user,
            enablePersistence: widget.enablePersistence,
            callbacks: chatwootCallbacks)
        .then((client) {
      setState(() {
        chatwootClient = client;
        chatwootClient!.loadMessages();
      });
    }).onError((error, stackTrace) {
      widget.onError?.call(ChatwootClientException(
          error.toString(), ChatwootClientExceptionType.CREATE_CLIENT_FAILED));
      print("chatwoot client failed with error $error: $stackTrace");
    });
  }

  types.TextMessage _chatwootMessageToTextMessage(ChatwootMessage message, {String? echoId}) {
    String? avatarUrl = message.sender?.avatarUrl ?? message.sender?.thumbnail;

    if (message.sender == null) {
      return types.TextMessage(
          id: echoId ?? message.id.toString(),
          text: message.content ?? "",
          previewData: types.PreviewData(link: message.content!),
          createdAt: DateTime.parse(message.createdAt).millisecondsSinceEpoch,
          author: types.User(
              id: 'sxcGaVTkvg',
              firstName: "Bot",
              imageUrl:
                  "https://d2cbg94ubxgsnp.cloudfront.net/Pictures/480x270//9/9/3/512993_shutterstock_715962319converted_920340.png"),
          status: types.Status.delivered);
    }

    //Sets avatar url to null if its a gravatar not found url
    //This enables placeholder for avatar to show
    if (avatarUrl?.contains("?d=404") ?? false) {
      avatarUrl = null;
    }
    return types.TextMessage(
        id: echoId ?? message.id.toString(),
        author: message.isMine
            ? _user
            : types.User(
                id: message.sender?.id.toString() ?? idGen.v4(),
                firstName: message.sender?.name,
                imageUrl: avatarUrl,
              ),
        text: message.content ?? "",
        status: types.Status.seen,
        createdAt: DateTime.parse(message.createdAt).millisecondsSinceEpoch);
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _handleSendMessageFailed(String echoId) async {
    final index = _messages.indexWhere((element) => element.id == echoId);
    setState(() {
      _messages[index] = _messages[index].copyWith(status: types.Status.error);
    });
  }

  void _handleResendMessage(types.TextMessage message) async {
    chatwootClient!.sendMessage(content: message.text, echoId: message.id);
    final index = _messages.indexWhere((element) => element.id == message.id);
    setState(() {
      _messages[index] = message.copyWith(status: types.Status.sending);
    });
  }

  void _handleMessageTap(BuildContext context, types.Message message) async {
    if (message.status == types.Status.error && message is types.TextMessage) {
      _handleResendMessage(message);
    }

    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        try {
          final index = _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage = (_messages[index] as types.FileMessage).copyWith(
            isLoading: true,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });

          final client = http.Client();
          final request = await client.get(Uri.parse(message.uri));
          final bytes = request.bodyBytes;
          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';

          if (!File(localPath).existsSync()) {
            final file = File(localPath);
            await file.writeAsBytes(bytes);
          }
        } finally {
          final index = _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage = (_messages[index] as types.FileMessage).copyWith(
            isLoading: null,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });
        }
      }

      await OpenFilex.open(localPath);
    }
    widget.onMessageTap?.call(message);
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage =
        (_messages[index] as types.TextMessage).copyWith(previewData: previewData);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _messages[index] = updatedMessage;
      });
    });
  }

  void _handleMessageSent(
    types.Message message,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);

    if (_messages[index].status == types.Status.seen) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _messages[index] = message;
      });
    });
  }

  void _handleMessageUpdated(
    types.Message message,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _messages[index] = message;
      });
    });
  }

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: message.text,
        status: types.Status.sending);

    _addMessage(textMessage);

    chatwootClient!.sendMessage(content: textMessage.text, echoId: textMessage.id);
    widget.onSendPressed?.call(message);
  }

  // void _handleAttachmentPressed() {
  //   widget.onAttachmentPressed?.call();
  // }

  @override
  Widget build(BuildContext context) {
    // final horizontalPadding = widget.isPresentedInDialog ? 8.0 : 16.0;
    // ChatwootChatTheme theme = widget.theme ?? ChatwootChatTheme();
    return Scaffold(
      appBar: widget.appBar,
      // backgroundColor: theme.backgroundColor,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
          child: Column(
            children: [
              Flexible(
                // child: Padding(
                // padding: EdgeInsets.only(left: horizontalPadding, right: horizontalPadding),
                child: Chat(
                  messages: _messages,
                  onMessageTap: _handleMessageTap,
                  onPreviewDataFetched: _handlePreviewDataFetched,
                  onSendPressed: _handleSendPressed,
                  // onAttachmentPressed: _handleAttachmentPressed,
                  user: _user,
                  onEndReached: widget.onEndReached,
                  onEndReachedThreshold: widget.onEndReachedThreshold,
                  onMessageLongPress: widget.onMessageLongPress,
                  inputOptions: InputOptions(
                    sendButtonVisibilityMode: SendButtonVisibilityMode.always,
                    onTextChanged: widget.onTextChanged,
                  ),

                  showUserAvatars: widget.showUserAvatars,
                  showUserNames: widget.showUserNames,
                  timeFormat: widget.timeFormat ?? DateFormat.Hm(),
                  dateFormat: widget.timeFormat ?? DateFormat("EEEE MMMM d"),
                  theme: DefaultChatTheme(
                      backgroundColor: Color.fromRGBO(248, 250, 255, 1),
                      inputBackgroundColor: Color.fromRGBO(255, 255, 255, 1),
                      inputTextColor: Color.fromRGBO(16, 30, 50, 1),
                      sendButtonIcon: SvgPicture.asset('assets/send.svg',
                          package: 'chatwoot_sdk', semanticsLabel: 'Send button'),
                      secondaryColor: Color.fromRGBO(253, 246, 235, 1),
                      primaryColor: Color.fromRGBO(173, 153, 212, 1),
                      userAvatarImageBackgroundColor: Color.fromRGBO(0, 102, 245, 1),
                      sentMessageBodyBoldTextStyle: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      sentMessageBodyCodeTextStyle: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white),
                      sentMessageBodyTextStyle: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white),
                      receivedMessageBodyBoldTextStyle: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black),
                      receivedMessageBodyCodeTextStyle: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.black),
                      receivedMessageBodyTextStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          fontSize: 13, fontWeight: FontWeight.w400, color: Colors.black)),
                  l10n: widget.l10n,
                  usePreviewData: true,
                ),
                // ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Color.fromRGBO(249, 249, 251, 1),
                width: MediaQuery.of(context).size.width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/logo_grey.png",
                      package: 'chatwoot_sdk',
                      width: 15,
                      height: 15,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        "Powered by Chatwoot",
                        style: TextStyle(color: Colors.black45, fontSize: 12),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
          onRefresh: () async {
            chatwootClient?.loadMessages();
            setState(() {});
          }),
    );
  }

  @override
  void dispose() {
    super.dispose();
    chatwootClient?.dispose();
  }
}
