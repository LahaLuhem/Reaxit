import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reaxit/models/photo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:reaxit/api/exceptions.dart';
import 'package:reaxit/models.dart';
import 'package:reaxit/ui/theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:reaxit/ui/widgets/cached_image.dart';

abstract class GalleryCubit<T> extends StateStreamableSource<T> {
  Future<void> updateLike({required bool liked, required int index});
  Future<void> more();
}

class Gallery<C extends GalleryCubit> extends StatefulWidget {
  final List<AlbumPhoto> photos;
  final int initialPage;
  final int photoAmount;

  const Gallery({
    required this.photos,
    required this.initialPage,
    required this.photoAmount,
  });

  @override
  State<Gallery> createState() => _GalleryState<C>();
}

class _GalleryState<C extends GalleryCubit> extends State<Gallery>
    with TickerProviderStateMixin {
  late final PageController controller;

  late final AnimationController likeController;
  late final AnimationController unlikeController;
  late final Animation<double> likeAnimation;
  late final Animation<double> unlikeAnimation;

  @override
  void initState() {
    super.initState();
    controller = PageController(initialPage: widget.initialPage);

    likeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
      upperBound: 0.8,
    )..addStatusListener(
      (status) =>
          status == AnimationStatus.completed ? likeController.reset() : null,
    );

    unlikeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
      upperBound: 0.8,
    )..addStatusListener(
      (status) =>
          status == AnimationStatus.completed ? unlikeController.reset() : null,
    );

    unlikeAnimation = CurvedAnimation(
      parent: unlikeController,
      curve: Curves.elasticOut,
    );
    likeAnimation = CurvedAnimation(
      parent: likeController,
      curve: Curves.elasticOut,
    );
  }

  Future<void> _downloadImage(Uri url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) throw Exception();
      final baseTempDir = await getTemporaryDirectory();
      final tempDir = await baseTempDir.createTemp();
      final tempFile = File('${tempDir.path}/${url.pathSegments.last}');
      await tempFile.writeAsBytes(response.bodyBytes);
      await Gal.putImage(tempFile.path);

      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Succesfully saved the image.'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not download the image.'),
        ),
      );
    }
  }

  Future<void> _shareImage(Uri url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) throw Exception();
      final file = XFile.fromData(
        response.bodyBytes,
        mimeType: lookupMimeType(url.path, headerBytes: response.bodyBytes),
        name: url.pathSegments.last,
      );
      await Share.shareXFiles([file]);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not share the image.'),
        ),
      );
    }
  }

  Future<void> _likePhoto(List<AlbumPhoto> photos, int index) async {
    final messenger = ScaffoldMessenger.of(context);
    likeController.forward();
    try {
      await BlocProvider.of<C>(context).updateLike(liked: true, index: index);
    } on ApiException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while liking the photo.'),
        ),
      );
    }
  }

  Future<void> _toggleLikePhoto(List<AlbumPhoto> photos, int index) async {
    final messenger = ScaffoldMessenger.of(context);
    if (photos[index].liked) {
      unlikeController.forward();
    } else {
      likeController.forward();
    }
    try {
      await BlocProvider.of<C>(
        context,
      ).updateLike(liked: !photos[index].liked, index: index);
    } on ApiException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while liking the photo.'),
        ),
      );
    }
  }

  Future<void> _loadMorePhotos() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BlocProvider.of<C>(context).more();
    } on ApiException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while loading the photos.'),
        ),
      );
    }
  }

  Widget _gallery(List<AlbumPhoto> photos) {
    return PhotoViewGallery.builder(
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      pageController: controller,
      itemCount: widget.photoAmount,
      loadingBuilder:
          (_, __) => const Center(child: CircularProgressIndicator()),
      builder: (context, i) {
        final Widget child;

        if (i < photos.length) {
          child = GestureDetector(
            onDoubleTap: () => _likePhoto(photos, i),
            child: RotatedBox(
              quarterTurns: photos[i].rotation ~/ 90,
              child: CachedImage(imageUrl: photos[i].full, fit: BoxFit.contain),
            ),
          );
        } else {
          child = const Center(child: CircularProgressIndicator());
        }

        return PhotoViewGalleryPageOptions.customChild(
          child: child,
          minScale: PhotoViewComputedScale.contained * 1,
          maxScale: PhotoViewComputedScale.covered * 2,
        );
      },
    );
  }

  Widget _downloadButton(List<AlbumPhoto> photos) {
    return IconButton(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryIconTheme.color,
      icon: const Icon(Icons.download),
      onPressed:
          () =>
              _downloadImage(Uri.parse(photos[controller.page!.round()].full)),
    );
  }

  Widget _shareButton(List<AlbumPhoto> photos) {
    return IconButton(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryIconTheme.color,
      icon: Icon(Icons.adaptive.share),
      onPressed:
          () => _shareImage(Uri.parse(photos[controller.page!.floor()].full)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget overlayScaffold = Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading: CloseButton(
          color: Theme.of(context).primaryIconTheme.color,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [_downloadButton(widget.photos), _shareButton(widget.photos)],
      ),
      body: Stack(
        children: [
          _gallery(widget.photos),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: _PageCounter(
                controller,
                widget.initialPage,
                widget.photos,
                widget.photoAmount,
                _toggleLikePhoto,
                _loadMorePhotos,
              ),
            ),
          ),
        ],
      ),
    );

    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        overlayScaffold,
        HeartPopup(animation: unlikeAnimation, color: Colors.white),
        HeartPopup(animation: likeAnimation, color: magenta),
      ],
    );
  }
}

class HeartPopup extends StatelessWidget {
  const HeartPopup({super.key, required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: animation,
      child: Center(
        child: Icon(
          Icons.favorite,
          size: 70,
          color: color,
          shadows: const [
            BoxShadow(color: Colors.black54, spreadRadius: 20, blurRadius: 20),
          ],
        ),
      ),
    );
  }
}

class _PageCounter extends StatefulWidget {
  final PageController controller;
  final int initialPage;
  final List<AlbumPhoto> photos;
  final int photoAmount;
  final void Function(List<AlbumPhoto> photos, int index) toggleLikePhoto;
  final void Function() loadMorePhotos;

  const _PageCounter(
    this.controller,
    this.initialPage,
    this.photos,
    this.photoAmount,
    this.toggleLikePhoto,
    this.loadMorePhotos,
  );

  @override
  State<_PageCounter> createState() => __PageCounterState();
}

class __PageCounterState extends State<_PageCounter> {
  late int currentIndex;

  void onPageChange() {
    final newIndex = widget.controller.page!.round();

    if (newIndex == widget.photos.length - 1) {
      widget.loadMorePhotos();
    }

    if (newIndex != currentIndex) {
      setState(() => currentIndex = newIndex);
    }
  }

  @override
  void initState() {
    currentIndex = widget.initialPage;
    widget.controller.addListener(onPageChange);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(onPageChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    List<Widget> children = [
      Text(
        '${currentIndex + 1} / ${widget.photoAmount}',
        style: textTheme.bodyLarge?.copyWith(fontSize: 24, color: Colors.white),
      ),
    ];

    if (currentIndex < widget.photos.length) {
      final photo = widget.photos[currentIndex];

      children.addAll([
        Tooltip(
          message: photo.liked ? 'unlike photo' : 'like photo',
          child: IconButton(
            iconSize: 24,
            icon: Icon(
              color: photo.liked ? magenta : Colors.white,
              photo.liked ? Icons.favorite : Icons.favorite_outline,
            ),
            onPressed: () {
              widget.toggleLikePhoto(widget.photos, currentIndex);
              // Force update to set liked icon and count correctly
              setState(() {});
            },
          ),
        ),
        Text(
          '${photo.numLikes}',
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
      ]);
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
  }
}
