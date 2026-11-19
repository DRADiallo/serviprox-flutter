import 'dart:convert';

class ChampCommandeModel {
  final String code;
  final String label;
  final String type;
  final List<String> valeurs;
  final bool requis;

  const ChampCommandeModel({
    required this.code,
    required this.label,
    required this.type,
    this.valeurs = const [],
    this.requis = true,
  });

  factory ChampCommandeModel.fromJson(Map<String, dynamic> json) {
    return ChampCommandeModel(
      code:    json['code']   ?? '',
      label:   json['label']  ?? '',
      type:    json['type']   ?? 'TEXT',
      valeurs: List<String>.from(json['valeurs'] ?? []),
      requis:  json['requis'] ?? true,
    );
  }
}

class ConfigPrestataireModel {
  final bool avecAgent;
  final int prestataireId;
  final String nomPrestataire;   // ← était nomCommercial
  final String typeService;      // ← NOUVEAU
  final bool disponible;
  final String? champsCommandeJson;
  final String? etapesEffectivesJson;
  final String? modesDepotAcceptesJson;
  final String? typesPrestationJson;

  const ConfigPrestataireModel({
    required this.avecAgent,
    required this.prestataireId,
    required this.nomPrestataire,
    required this.typeService,
    required this.disponible,
    this.champsCommandeJson,
    this.etapesEffectivesJson,
    this.modesDepotAcceptesJson,
    this.typesPrestationJson,
  });

  // ── Étapes effectives (résolues côté serveur) ─────────
  List<String> get etapesEffectives {
    try {
      if (etapesEffectivesJson == null) return [];
      return List<String>.from(jsonDecode(etapesEffectivesJson!));
    } catch (_) {
      return [];
    }
  }

  // ── Modes de dépôt ─────────────────────────────────────
  List<String> get modesDepotEffectifs {
    try {
      if (modesDepotAcceptesJson == null) return [];
      return List<String>.from(jsonDecode(modesDepotAcceptesJson!));
    } catch (_) {
      return [];
    }
  }

  // ── Champs du formulaire (Couche 2) ───────────────────
  List<ChampCommandeModel> get champsCommande {
    try {
      if (champsCommandeJson == null) return [];
      final List<dynamic> list = jsonDecode(champsCommandeJson!);
      return list.map((e) =>
        ChampCommandeModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Prestations proposées (Couche 1 + config) ─────────
  List<Map<String, dynamic>> get typesPrestation {
    try {
      if (typesPrestationJson == null) return [];
      final List<dynamic> list = jsonDecode(typesPrestationJson!);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  factory ConfigPrestataireModel.fromJson(Map<String, dynamic> json) {
    return ConfigPrestataireModel(
      avecAgent:            json['avecAgent']         ?? false,
      prestataireId:        json['prestataireId']     ?? 0,
      nomPrestataire:       json['nomPrestataire']    ?? '',  // ← corrigé
      typeService:          json['typeService']       ?? '',  // ← NOUVEAU
      disponible:           json['disponible']        ?? true,
      champsCommandeJson:   json['champsCommande'],
      etapesEffectivesJson: json['etapesEffectives'],
      modesDepotAcceptesJson: json['modesDepotAcceptes'],
      typesPrestationJson:  json['typesPrestation'],
    );
  }
}