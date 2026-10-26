class PackageBankTransfer {
  final int purchaseId;
  final double amount;
  final String status, bankName, accountNumber, accountName;
  final String transferContent, qrImageUrl;

  PackageBankTransfer.fromJson(Map<String, dynamic> json)
    : purchaseId = (json['purchaseId'] as num).toInt(),
      amount = (json['amount'] as num).toDouble(),
      status = json['status'] as String,
      bankName = json['bankName'] as String,
      accountNumber = json['accountNumber'] as String,
      accountName = json['accountName'] as String,
      transferContent = json['transferContent'] as String,
      qrImageUrl = json['qrImageUrl'] as String;
}
