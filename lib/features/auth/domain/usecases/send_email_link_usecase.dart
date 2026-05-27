import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

class SendEmailLinkUseCase implements UseCase<void, SendEmailLinkParams> {
  final AuthRepository repository;

  SendEmailLinkUseCase(this.repository);

  @override
  Future<void> call(SendEmailLinkParams params) async {
    await repository.sendEmailLink(email: params.email);
  }
}

class SendEmailLinkParams extends Equatable {
  final String email;

  const SendEmailLinkParams({required this.email});

  @override
  List<Object?> get props => [email];
}
