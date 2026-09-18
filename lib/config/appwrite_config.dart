class AppwriteConfig {
  static const String projectId = '6972fc1c001816b0de41';
  static const String projectName = 'Tap_It';
  static const String endpoint = 'https://appwrite.aigenxt.com/v1';

  // Database configuration
  static const String databaseId = 'Tap_It_DB';
  static const String transactionsCollectionId = 'transactions';
  static const String categoriesCollectionId = 'categories';
  static const String itemsCollectionId = 'items';
  static const String profilesCollectionId = 'profiles';
  static const String ledgerCollectionId = 'ledger_transactions';
  static const String notificationsCollectionId = 'notifications';
  static const String investmentsCollectionId = 'investments';
  static const String investmentTransactionsCollectionId =
      'investment_transactions';

  static const String dutchGroupsCollectionId = 'dutch_groups';
  static const String dutchExpensesCollectionId = 'dutch_expenses';
  static const String dutchSettlementsCollectionId = 'dutch_settlements';
  static const String goalsCollectionId = 'goals';

  // Functions
  static const String createGroupFunctionId = '697da27000261462e47c';
  static const String shareTransactionFunctionId = '697b2e5a00268c4ab313';
  static const String createExpenseFunctionId = '697dbd05002101132988';
  static const String createSettlementFunctionId = '697dbdf800045dbe9e6a';
  static const String joinGroupFunctionId = '698434a1000203f0d76c';
  static const String resetPasswordFunctionId = '6a6c6f3c0038c556c056';

  // Storage
  static const String profilePhotosBucketId = 'profile_photos';
}
