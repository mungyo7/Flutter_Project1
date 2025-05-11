import 'package:flutter/material.dart';

// 앱 색상 테마
class AppColors {
  // 메인 색상
  static const primary = Color(0xFFB2FF00);
  static const background = Colors.black;
  static const inputBackground = Color(0xFF1A1A1A);
  static const textLight = Colors.white;
  static const textDark = Colors.black;
  static const hintText = Colors.grey;
  static const error = Colors.red;
  static const success = Colors.green;
}

// 텍스트 스타일
class AppTextStyle {
  // 제목 스타일
  static const title = TextStyle(
    color: AppColors.primary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  // 라벨 스타일
  static const label = TextStyle(
    color: AppColors.textLight,
    fontSize: 14,
  );

  // 버튼 텍스트 스타일
  static const buttonText = TextStyle(
    color: AppColors.textDark,
    fontWeight: FontWeight.bold,
    fontSize: 16,
  );

  // 링크 텍스트 스타일
  static const linkText = TextStyle(
    color: AppColors.primary,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  // 일반 텍스트 스타일
  static const bodyText = TextStyle(
    color: AppColors.textLight,
    fontSize: 14,
  );
}

// 입력 필드 장식
class AppDecorations {
  // 입력 필드 장식
  static InputDecoration inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: AppColors.hintText),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      suffixIcon: const Icon(
        Icons.check_circle,
        color: AppColors.primary,
      ),
    );
  }

  // 입력 필드 컨테이너 장식
  static BoxDecoration inputBoxDecoration() {
    return BoxDecoration(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: AppColors.primary, width: 1),
    );
  }

  // 메인 컨테이너 장식
  static BoxDecoration mainBoxDecoration() {
    return BoxDecoration(
      border: Border.all(color: AppColors.primary, width: 1),
    );
  }
}

// 버튼 스타일
class AppButtonStyle {
  // 기본 버튼 스타일
  static ButtonStyle primaryButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      elevation: 0,
    );
  }
}

// 표준 위젯 간격
class AppSpacing {
  static const small = 8.0;
  static const medium = 15.0;
  static const large = 20.0;
  static const xlarge = 30.0;
}

// 구분선
class AppDividers {
  static const primary = Divider(
    color: AppColors.primary,
    thickness: 1,
  );
}

// 스낵바 유틸리티
class AppSnackBar {
  // 성공 메시지 스낵바
  static void showSuccess(BuildContext context, String message) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }
  
  // 오류 메시지 스낵바
  static void showError(BuildContext context, String message) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
} 