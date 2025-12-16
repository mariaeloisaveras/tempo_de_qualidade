# Plano de testes manuais de localização e permissões

Este roteiro descreve verificações para entrada/saída de geofences com localização simulada e o comportamento do aplicativo em cenários de economia de bateria e permissão "Não Perturbe" (DND).

## Preparação
- Configurar uma chave válida da Google Places API em `lib/main.dart` e rodar `flutter pub get`.
- Garantir que o dispositivo ou emulador tem serviços de localização habilitados.
- Habilitar a sobreposição de localização simulada no dispositivo real, ou confirmar que o emulador está com localização configurável via ADB.
- Compilar e instalar a aplicação (`flutter run`) antes dos testes.

## 1. Entrada/saída de geofence em emulador (ADB)
1. Iniciar o emulador Android e conectar via ADB (`adb devices`).
2. Abrir o aplicativo e permitir acesso à localização quando solicitado.
3. Criar uma geofence longa-pressionando o mapa e informando um raio; salvar.
4. Simular a localização dentro do raio usando `adb emu geo fix <lng> <lat>` (long/lat invertidos pelo comando do emulador). Confirmar que o marcador "Minha localização" aparece dentro do círculo e que o estado visual permanece estável.
5. Enviar uma posição fora do raio com novo `adb emu geo fix ...` e observar a transição de saída (o mapa deve mostrar a nova posição fora da área). Repetir alternando dentro/fora para validar consistência.

## 2. Entrada/saída em dispositivo real
1. Conectar o aparelho via USB ou Wi-Fi e habilitar localização simulada (ou realizar o teste em campo).
2. Abrir o app, conceder permissão de localização e criar uma geofence conforme o cenário anterior.
3. Usando uma ferramenta de mock location (ou deslocando-se fisicamente), posicionar-se dentro do raio e verificar se o mapa reflete a posição e mantém o círculo.
4. Mover-se para fora da área e confirmar a transição de saída. Repetir alguns ciclos para observar estabilidade (sem travamentos ou atrasos excessivos).

## 3. Doze/otimização de bateria desativada
1. Nas configurações do Android, localizar o aplicativo e desativar a otimização de bateria/Doze para ele.
2. Com uma geofence ativa, colocar o dispositivo em repouso (tela apagada) por alguns minutos.
3. Simular movimento de entrada/saída (via `adb emu geo fix` no emulador ou mock location no dispositivo real) enquanto o aparelho está em standby.
4. Retomar a tela e verificar se o app manteve o estado (geofence e posição) sem quedas ou reinícios inesperados.

## 4. Permissão DND ("Não Perturbe")
1. Se o fluxo do app solicitar acesso à permissão DND, negar na primeira apresentação.
2. Verificar se o aplicativo continua funcional (mapa, criação de geofence) e exibe mensagem clara e discreta informando que o modo DND é opcional ou necessário apenas para notificações.
3. Testar concedendo a permissão em seguida e confirmar que o app reage sem exigir reinício.

## 5. Observações de UX e logs
- Registrar eventuais mensagens de erro no Logcat (`adb logcat`) ao alternar localização ou ao negar permissões.
- Anotar latência percebida entre o envio de coordenadas simuladas e a atualização do mapa.
- Reportar qualquer falha de renderização, travamento ou perda de geofences durante as transições.
