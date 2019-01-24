import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:find_room/app/app.dart';
import 'package:find_room/generated/i18n.dart';
import 'package:find_room/pages/saved/saved_bloc.dart';
import 'package:find_room/pages/saved/saved_state.dart';
import 'package:find_room/user_bloc/user_bloc.dart';
import 'package:find_room/user_bloc/user_login_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SavedPage extends StatefulWidget {
  final UserBloc userBloc;
  final SavedBloc Function() initSavedBloc;

  const SavedPage({
    Key key,
    @required this.userBloc,
    @required this.initSavedBloc,
  }) : super(key: key);

  _SavedPageState createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  SavedBloc _savedBloc;
  List<StreamSubscription> _subscriptions;

  @override
  void initState() {
    super.initState();

    _savedBloc = widget.initSavedBloc();
    _subscriptions = [
      widget.userBloc.userLoginState$
          .where((state) => state is NotLogin)
          .listen((_) => Navigator.popUntil(context, ModalRoute.withName('/'))),
      _savedBloc.removeMessage$.listen(_showMessageResult),
    ];
  }

  void _showMessageResult(SavedMessage message) {
    print('[DEBUG] saved_message=$message');
    final s = S.of(context);

    if (message is RemovedSaveRoomMessage) {
      if (message is RemovedSaveRoomMessageSuccess) {
        _showSnackBar(
            s.remove_saved_room_success_with_title(message.removedTitle));
      }
      if (message is RemovedSaveRoomMessageError) {
        if (message.error is NotLoginError) {
          _showSnackBar(s.require_login);
        } else {
          _showSnackBar(s.remove_saved_room_error);
        }
      }
    }
  }

  _showSnackBar(String message) {
    Scaffold.of(context).showSnackBar(
      SnackBar(
        duration: Duration(seconds: 2),
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _subscriptions.forEach((s) => s.cancel());
    _savedBloc.dispose();
    print('_SavedPageState#dispose');

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).saved_rooms_title),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => RootScaffold.openDrawer(context),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<SavedListState>(
            stream: _savedBloc.savedListState$,
            initialData: _savedBloc.savedListState$.value,
            builder: (context, snapshot) {
              var data = snapshot.data;
              print('saved length=${data.roomItems.length}, data=$data');

              if (data.error != null) {
                return Center(
                  child: Text(
                    S.of(context).error_occurred,
                    style: Theme.of(context).textTheme.subhead,
                  ),
                );
              }

              if (data.isLoading) {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (data.roomItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.home,
                        size: 48,
                        color: Theme.of(context).accentColor,
                      ),
                      Text(
                        S.of(context).saved_list_empty,
                        style: Theme.of(context)
                            .textTheme
                            .body1
                            .copyWith(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: data.roomItems.length,
                physics: BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  var padding = _getItemPadding(data.roomItems.length, index);
                  return SavedRoomListItem(
                    roomItem: data.roomItems[index],
                    padding: padding,
                    removeFromSaved: _savedBloc.removeFromSaved.add,
                  );
                },
              );
            }),
      ),
    );
  }

  static EdgeInsets _getItemPadding(int length, int index) {
    EdgeInsets padding;
    if (length > 1) {
      if (index == 0) {
        padding = const EdgeInsets.fromLTRB(4, 4, 4, 2);
      } else if (index == length - 1) {
        padding = const EdgeInsets.fromLTRB(4, 2, 4, 4);
      } else {
        padding = const EdgeInsets.symmetric(
          vertical: 2,
          horizontal: 4,
        );
      }
    } else {
      padding = const EdgeInsets.all(4);
    }
    return padding;
  }
}

class SavedRoomListItem extends StatefulWidget {
  final RoomItem roomItem;
  final EdgeInsetsGeometry padding;
  final void Function(String) removeFromSaved;

  const SavedRoomListItem({
    Key key,
    @required this.roomItem,
    @required this.padding,
    @required this.removeFromSaved,
  }) : super(key: key);

  @override
  _SavedRoomListItemState createState() => _SavedRoomListItemState();
}

class _SavedRoomListItemState extends State<SavedRoomListItem>
    with SingleTickerProviderStateMixin<SavedRoomListItem> {
  AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final s = S.of(context);
    final item = widget.roomItem;

    return SlideTransition(
      position: Tween(
        begin: Offset(200, 0),
        end: Offset(0, 0),
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.fastOutSlowIn,
        ),
      ),
      child: Container(
        color: Colors.white,
        padding: widget.padding,
        child: Dismissible(
          background: Container(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  SizedBox(width: 16.0),
                  Icon(
                    Icons.delete,
                    size: 28.0,
                  ),
                  Text(
                    s.removed,
                    style: themeData.textTheme.subhead,
                  ),
                  Spacer(),
                  Text(
                    s.removed,
                    style: themeData.textTheme.subhead,
                  ),
                  SizedBox(width: 16.0),
                  Icon(
                    Icons.delete,
                    size: 28.0,
                  ),
                ],
              ),
            ),
          ),
          direction: DismissDirection.horizontal,
          onDismissed: (direction) {
            print('onDismissed direction=$direction');
            widget.removeFromSaved(item.id);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  child: CachedNetworkImage(
                    width: 128,
                    height: 128,
                    fit: BoxFit.cover,
                    imageUrl: item.image,
                    placeholder: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    errorWidget: Center(
                      child: Icon(Icons.image),
                    ),
                  ),
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: themeData.textTheme.subtitle.copyWith(
                          fontSize: 14,
                          fontFamily: 'SF-Pro-Text',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.price,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: themeData.textTheme.subtitle.copyWith(
                          color: themeData.accentColor,
                          fontSize: 12.0,
                          fontFamily: 'SF-Pro-Text',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        item.address,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: themeData.textTheme.subtitle.copyWith(
                          color: Colors.black87,
                          fontSize: 12,
                          fontFamily: 'SF-Pro-Text',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        item.districtName,
                        maxLines: 1,
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        style: themeData.textTheme.subtitle.copyWith(
                          color: Colors.black87,
                          fontSize: 12,
                          fontFamily: 'SF-Pro-Text',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              DateFormat.yMMMMd().add_Hms().format(item.savedTime),
                              maxLines: 1,
                              textAlign: TextAlign.left,
                              overflow: TextOverflow.ellipsis,
                              style: themeData.textTheme.subtitle.copyWith(
                                color: Colors.black54,
                                fontSize: 12,
                                fontFamily: 'SF-Pro-Text',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Icon(Icons.bookmark),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          key: Key(item.id),
        ),
      ),
    );
  }
}
