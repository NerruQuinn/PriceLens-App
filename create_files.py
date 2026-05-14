import os

base_dir = r"C:\Users\User\Documents\1ST APPS\Price Comparison Apps\pricelens_id\lib"

files_to_create = [
    "firebase_options.dart",
    "core/constants/app_colors.dart",
    "core/constants/app_strings.dart",
    "core/constants/gemini_prompts.dart",
    "core/theme/skin_theme_resolver.dart",
    "core/utils/price_validator.dart",
    "core/utils/point_calculator.dart",
    "core/utils/image_helper.dart",
    "data/models/product_model.dart",
    "data/models/price_entry_model.dart",
    "data/models/submission_model.dart",
    "data/models/basket_model.dart",
    "data/models/user_model.dart",
    "data/models/skin_model.dart",
    "data/repositories/product_repository.dart",
    "data/repositories/price_repository.dart",
    "data/repositories/submission_repository.dart",
    "data/repositories/user_repository.dart",
    "data/repositories/basket_repository.dart",
    "data/services/gemini_service.dart",
    "data/services/firestore_service.dart",
    "data/services/auth_service.dart",
    "data/services/storage_service.dart",
    "data/services/cache_service.dart",
    "presentation/screens/auth/login_screen.dart",
    "presentation/screens/home/home_screen.dart",
    "presentation/screens/scan/camera_screen.dart",
    "presentation/screens/result/price_result_screen.dart",
    "presentation/screens/basket/basket_estimator_screen.dart",
    "presentation/screens/submit/price_submission_screen.dart",
    "presentation/screens/profile/profile_screen.dart",
    "presentation/screens/shop/skin_shop_screen.dart",
    "presentation/screens/explore/explore_screen.dart",
    "presentation/widgets/price_card.dart",
    "presentation/widgets/comparison_table.dart",
    "presentation/widgets/smart_advisor_card.dart",
    "presentation/widgets/trend_chart.dart",
    "presentation/widgets/legit_badge.dart",
    "presentation/widgets/point_badge.dart",
    "presentation/widgets/basket_item_tile.dart",
    "providers/auth_provider.dart",
    "providers/product_provider.dart",
    "providers/basket_provider.dart",
    "providers/submission_provider.dart",
    "providers/user_provider.dart",
    "providers/skin_provider.dart"
]

for file_path in files_to_create:
    full_path = os.path.join(base_dir, file_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w") as f:
        f.write("// TODO: implement\n")
