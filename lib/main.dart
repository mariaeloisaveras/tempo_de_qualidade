import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:flutter_dnd/flutter_dnd.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GeofenceApp());
}

class GeofenceApp extends StatelessWidget {
  const GeofenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tempo de Qualidade',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GeofenceHomePage(),
    );
  }
}

class GeofenceHomePage extends StatefulWidget {
  const GeofenceHomePage({super.key});

  @override
  State<GeofenceHomePage> createState() => _GeofenceHomePageState();
}

class _GeofenceHomePageState extends State<GeofenceHomePage> {
  static const _fallbackPosition = LatLng(-23.5505, -46.6333);
  static const _googleApiKey = 'YOUR_GOOGLE_API_KEY';

  late final TextEditingController _radiusController;
  late final TextEditingController _searchController;
  GooglePlace? _googlePlace;
  GoogleMapController? _mapController;
  LatLng _cameraPosition = _fallbackPosition;
  LatLng? _selectedPosition;
  final List<_SavedGeofence> _geofences = [];
  List<AutocompletePrediction> _predictions = [];
  Timer? _debounce;
  bool _locationServiceEnabled = false;
  LocationPermission? _locationPermission;
  bool _dndAccessGranted = false;
  bool _dndEnabled = false;

  @override
  void initState() {
    super.initState();
    _radiusController = TextEditingController(text: '200');
    _searchController = TextEditingController();
    _googlePlace = _googleApiKey == 'YOUR_GOOGLE_API_KEY'
        ? null
        : GooglePlace(_googleApiKey);
    _initLocation();
    _refreshStatuses();
  }

  @override
  void dispose() {
    _radiusController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Ative o serviço de localização para usar o mapa.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showMessage('Permita o acesso à localização para usar o mapa.');
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      _showMessage('Autorize a localização nas configurações do sistema.');
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _cameraPosition = LatLng(position.latitude, position.longitude);
      _locationPermission = permission;
      _locationServiceEnabled = serviceEnabled;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(_cameraPosition),
    );
  }

  Future<void> _refreshStatuses() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    bool dndGranted = false;
    bool dndActive = false;
    try {
      dndGranted = await FlutterDnd.isNotificationPolicyAccessGranted ?? false;
      final filter = await FlutterDnd.getCurrentInterruptionFilter();
      dndActive = filter != null &&
          filter != FlutterDnd.INTERRUPTION_FILTER_ALL &&
          filter != FlutterDnd.INTERRUPTION_FILTER_UNKNOWN;
    } catch (_) {
      dndGranted = false;
      dndActive = false;
    }

    setState(() {
      _locationServiceEnabled = serviceEnabled;
      _locationPermission = permission;
      _dndAccessGranted = dndGranted;
      _dndEnabled = dndActive;
    });
  }

  Future<void> _requestForegroundPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Ative o GPS para permitir localização em primeiro plano.');
      return;
    }

    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      _showMessage('Permissão negada. Autorize para ver sua posição.');
    } else if (permission == LocationPermission.deniedForever) {
      _showMessage('Permissão permanente negada. Ajuste nas configurações.');
    } else {
      _showMessage('Permissão de localização em uso concedida.');
    }

    await _refreshStatuses();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _initLocation();
    }
  }

  Future<void> _requestBackgroundPermission() async {
    if (!_locationServiceEnabled) {
      _showMessage('Ative o GPS antes de solicitar localização em segundo plano.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always) {
      _showMessage('Permissão de localização em segundo plano ativa.');
    } else if (permission == LocationPermission.deniedForever) {
      _showMessage('Conceda acesso em segundo plano nas configurações do sistema.');
    } else {
      _showMessage('Não foi possível habilitar localização em segundo plano.');
    }

    await _refreshStatuses();
  }

  Future<void> _openDndSettings() async {
    try {
      await FlutterDnd.gotoPolicySettings();
    } catch (_) {
      _showMessage('Não foi possível abrir as configurações de Não Perturbe.');
      return;
    }

    await _refreshStatuses();
    if (_dndAccessGranted) {
      _showMessage('Acesso ao Não Perturbe concedido.');
    } else {
      _showMessage('Permita o acesso ao Não Perturbe para controlar alertas.');
    }
  }

  String _locationPermissionLabel() {
    final permission = _locationPermission;
    if (!_locationServiceEnabled) return 'Serviço de localização desativado';
    switch (permission) {
      case LocationPermission.always:
        return 'Concedida (segundo plano)';
      case LocationPermission.whileInUse:
        return 'Concedida (em uso)';
      case LocationPermission.denied:
        return 'Negada';
      case LocationPermission.deniedForever:
        return 'Negada permanentemente';
      default:
        return 'Não solicitada';
    }
  }

  String _dndStatusLabel() {
    if (!_dndAccessGranted) return 'Acesso não concedido';
    return _dndEnabled ? 'Ativado' : 'Desativado';
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final geofence in _geofences) {
      markers.add(
        Marker(
          markerId: MarkerId(geofence.id),
          position: geofence.center,
          infoWindow: InfoWindow(
            title: 'Geofence ${geofence.id}',
            snippet: 'Raio: ${geofence.radius.toStringAsFixed(0)}m',
          ),
        ),
      );
    }

    if (_selectedPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selection'),
          position: _selectedPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Ponto selecionado'),
        ),
      );
    }

    return markers;
  }

  Set<Circle> _buildCircles() {
    final circles = <Circle>{};
    for (final geofence in _geofences) {
      circles.add(
        Circle(
          circleId: CircleId('circle_${geofence.id}'),
          center: geofence.center,
          radius: geofence.radius,
          strokeWidth: 2,
          fillColor: Colors.deepPurple.withOpacity(0.15),
          strokeColor: Colors.deepPurple,
        ),
      );
    }

    if (_selectedPosition != null) {
      final radius = double.tryParse(_radiusController.text) ?? 0;
      circles.add(
        Circle(
          circleId: const CircleId('selection_circle'),
          center: _selectedPosition!,
          radius: radius,
          strokeWidth: 1,
          strokeColor: Colors.blueGrey,
          fillColor: Colors.blueGrey.withOpacity(0.1),
        ),
      );
    }

    return circles;
  }

  void _onMapLongPress(LatLng position) {
    setState(() {
      _selectedPosition = position;
    });
  }

  void _saveGeofence() {
    final position = _selectedPosition;
    final radius = double.tryParse(_radiusController.text);

    if (position == null || radius == null || radius <= 0) {
      _showMessage('Selecione um ponto no mapa e informe um raio válido.');
      return;
    }

    final geofence = _SavedGeofence(
      id: (_geofences.length + 1).toString(),
      center: position,
      radius: radius,
    );

    setState(() {
      _geofences.add(geofence);
      _selectedPosition = null;
    });
    _showMessage('Geofence salvo.');
  }

  void _removeLastGeofence() {
    if (_geofences.isEmpty) {
      _showMessage('Não há geofences para remover.');
      return;
    }

    setState(() {
      _geofences.removeLast();
    });
    _showMessage('Geofence removido.');
  }

  void _showGeofenceList() {
    if (_geofences.isEmpty) {
      _showMessage('Nenhuma geofence ativa.');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _geofences.length,
        itemBuilder: (context, index) {
          final geofence = _geofences[index];
          return ListTile(
            leading: CircleAvatar(child: Text(geofence.id)),
            title: Text('Lat: ${geofence.center.latitude.toStringAsFixed(5)}'),
            subtitle: Text('Lng: ${geofence.center.longitude.toStringAsFixed(5)}'),
            trailing: Text('${geofence.radius.toStringAsFixed(0)} m'),
          );
        },
        separatorBuilder: (_, __) => const Divider(),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onSearchChanged(String value) {
    if (_googlePlace == null) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (value.isEmpty) {
        setState(() => _predictions = []);
        return;
      }

      final response = await _googlePlace!.autocomplete.get(value);
      if (response != null && response.predictions != null) {
        setState(() => _predictions = response.predictions!);
      }
    });
  }

  Future<void> _selectPrediction(AutocompletePrediction prediction) async {
    if (_googlePlace == null || prediction.placeId == null) return;

    final details = await _googlePlace!.details.get(prediction.placeId!);
    final location = details.result?.geometry?.location;
    if (location == null) return;

    final position = LatLng(location.lat ?? 0, location.lng ?? 0);
    setState(() {
      _selectedPosition = position;
      _predictions = [];
      _searchController.text = prediction.description ?? '';
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciador de Geofences'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado atual',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.location_pin),
                        title: const Text('Permissão de localização'),
                        subtitle: Text(_locationPermissionLabel()),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.do_not_disturb),
                        title: const Text('Acesso ao Não Perturbe'),
                        subtitle: Text(_dndStatusLabel()),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.adjust_rounded),
                        title: const Text('Geofences ativas'),
                        subtitle: Text('${_geofences.length} ativa(s)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _requestForegroundPermission,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Permitir localização em uso'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _requestBackgroundPermission,
                      icon: const Icon(Icons.location_history),
                      label: const Text('Permitir em segundo plano'),
                    ),
                    TextButton.icon(
                      onPressed: _openDndSettings,
                      icon: const Icon(Icons.settings_applications),
                      label: const Text('Permitir acesso ao Não Perturbe'),
                    ),
                    IconButton(
                      onPressed: _refreshStatuses,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Atualizar status',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    labelText: 'Buscar local (Places API)',
                    hintText: 'Digite um endereço ou ponto de interesse',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _predictions = []);
                      },
                    ),
                  ),
                ),
                if (_googlePlace == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Configure sua chave da Places API para habilitar o autocomplete.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                if (_predictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      itemBuilder: (context, index) {
                        final prediction = _predictions[index];
                        return ListTile(
                          title: Text(prediction.description ?? ''),
                          onTap: () => _selectPrediction(prediction),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _radiusController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Raio em metros',
                          prefixIcon: Icon(Icons.radar),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saveGeofence,
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _removeLastGeofence,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remover último'),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: _showGeofenceList,
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Geofences ativas'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _cameraPosition,
                zoom: 13,
              ),
              myLocationEnabled: true,
              onMapCreated: (controller) => _mapController = controller,
              markers: _buildMarkers(),
              circles: _buildCircles(),
              onLongPress: _onMapLongPress,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              compassEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedGeofence {
  const _SavedGeofence({
    required this.id,
    required this.center,
    required this.radius,
  });

  final String id;
  final LatLng center;
  final double radius;
}
