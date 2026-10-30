import 'package:flutter/material.dart';

import 'rating_stars_widget.dart';

class ReviewInputBottomSheet extends StatefulWidget {
  final Future<bool> Function(int rating, String comment) onSubmit;

  const ReviewInputBottomSheet({super.key, required this.onSubmit});

  @override
  State<ReviewInputBottomSheet> createState() => _ReviewInputBottomSheetState();
}

class _ReviewInputBottomSheetState extends State<ReviewInputBottomSheet> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Vui lòng chọn số sao.');
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập nhận xét.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final success = await widget.onSubmit(_rating, _commentController.text);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _error = 'Chưa gửi được đánh giá. Bạn hãy thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Viết đánh giá', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Chọn số sao và chia sẻ trải nghiệm của bạn.'),
          const SizedBox(height: 8),
          Center(
            child: RatingStarsWidget(
              rating: _rating.toDouble(),
              interactive: true,
              onRatingChanged: (value) => setState(() {
                _rating = value;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Nhận xét',
              hintText: 'Điều gì làm bạn ấn tượng?',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Gửi đánh giá'),
            ),
          ),
        ],
      ),
    ),
  );
}
