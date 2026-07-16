import 'package:flutter/material.dart';

/// カメラ撮影画面(S06)が、自分の上に他の画面がpushされて隠れたこと
/// (候補一覧画面への遷移等)を検知し、カメラプレビューを一時停止・再開する
/// ために使う(issue #272レビュー対応)。
final cameraScreenRouteObserver = RouteObserver<PageRoute<void>>();
