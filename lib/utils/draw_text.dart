import 'package:flutter/material.dart';

Widget drawText(String text, {TextStyle? style}) {
  return Text(
    text,
    style: style,
    overflow: TextOverflow.ellipsis,
    maxLines: 3,
  );
}
