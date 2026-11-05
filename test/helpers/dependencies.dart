import 'package:afterglow_app/app/dependencies.dart';
import 'package:flutter/widgets.dart';

/// テスト対象のウィジェットに [AppDependencies] を提供する。
///
/// アプリ本体と同じく [DependencyScope] で包むため、画面遷移先のページも
/// 同じ依存（モックの Firebase や差し替えた Repository）を受け取る。
/// `MaterialApp` の外側に置くこと。
Widget withDependencies(AppDependencies dependencies, Widget child) =>
    DependencyScope(dependencies: dependencies, child: child);
