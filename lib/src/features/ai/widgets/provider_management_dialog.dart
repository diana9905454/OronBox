import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/ai/ai_models.dart';
import 'package:oronbox/src/core/ai/ai_secret_store.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';

class ProviderManagementDialog extends StatefulWidget {
  const ProviderManagementDialog({super.key});

  @override
  State<ProviderManagementDialog> createState() =>
      _ProviderManagementDialogState();
}

class _ProviderManagementDialogState extends State<ProviderManagementDialog>
    with SingleTickerProviderStateMixin {
  List<AiProviderConfig> _providers = [];
  int _selectedProviderIndex = 0;
  TabController? _tabController;

  // 添加新提供商控制器
  final _newProviderNameController = TextEditingController(text: 'DeepSeek');
  final _newProviderUrlController = TextEditingController(
    text: 'https://api.deepseek.com',
  );
  final _newProviderApiKeyController = TextEditingController();
  bool _obscureNewKey = true;

  // 当前编辑供应商控制器
  final _editNameController = TextEditingController();
  final _editUrlController = TextEditingController();
  final _editApiKeyController = TextEditingController();
  bool _obscureEditKey = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _newProviderNameController.dispose();
    _newProviderUrlController.dispose();
    _newProviderApiKeyController.dispose();
    _editNameController.dispose();
    _editUrlController.dispose();
    _editApiKeyController.dispose();
    super.dispose();
  }

  void _initTabController() {
    _tabController?.dispose();
    if (_providers.isNotEmpty) {
      _tabController = TabController(
        length: _providers.length,
        vsync: this,
        initialIndex: _selectedProviderIndex.clamp(0, _providers.length - 1),
      );
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging &&
            _selectedProviderIndex != _tabController!.index) {
          setState(() {
            _selectedProviderIndex = _tabController!.index;
            _syncEditControllers();
          });
        }
      });
    } else {
      _tabController = null;
    }
  }

  Future<void> _loadProviders() async {
    final list = List<AiProviderConfig>.from(AiSettingsStore.providers);
    _providers = list;
    if (_selectedProviderIndex >= _providers.length) {
      _selectedProviderIndex = _providers.isEmpty ? 0 : _providers.length - 1;
    }
    _initTabController();
    await _syncEditControllers();
    if (mounted) setState(() {});
  }

  Future<void> _syncEditControllers() async {
    if (_selectedProviderIndex >= 0 &&
        _selectedProviderIndex < _providers.length) {
      final p = _providers[_selectedProviderIndex];
      _editNameController.text = p.name;
      _editUrlController.text = p.baseUrl;
      final key = await AiSecretStore.instance.getApiKey(p.credentialRef);
      if (mounted) {
        _editApiKeyController.text = key ?? '';
      }
    } else {
      _editNameController.clear();
      _editUrlController.clear();
      _editApiKeyController.clear();
    }
  }

  Future<void> _saveProviders() async {
    AiSettingsStore.providers = _providers;
    if (AiSettingsStore.activeProviderId == null && _providers.isNotEmpty) {
      AiSettingsStore.activeProviderId = _providers.first.id;
      if (_providers.first.models.isNotEmpty) {
        AiSettingsStore.activeModelId = _providers.first.models.first.modelId;
      }
    }
  }

  Future<void> _saveCurrentProviderBasic() async {
    if (_selectedProviderIndex < 0 ||
        _selectedProviderIndex >= _providers.length) {
      return;
    }
    final current = _providers[_selectedProviderIndex];
    final newName = _editNameController.text.trim();
    final newRawUrl = _editUrlController.text.trim();
    final newKey = _editApiKeyController.text.trim();

    if (newName.isEmpty || newRawUrl.isEmpty) return;

    final normalizedUrl = AiProviderConfig.normalizeBaseUrl(newRawUrl);
    final updated = AiProviderConfig(
      id: current.id,
      name: newName,
      baseUrl: normalizedUrl,
      credentialRef: current.credentialRef,
      models: current.models,
    );

    await AiSecretStore.instance.saveApiKey(current.credentialRef, newKey);

    setState(() {
      _providers[_selectedProviderIndex] = updated;
    });
    await _saveProviders();
  }

  Future<void> _addNewProvider() async {
    final name = _newProviderNameController.text.trim();
    final rawUrl = _newProviderUrlController.text.trim();
    final apiKey = _newProviderApiKeyController.text.trim();

    if (name.isEmpty || rawUrl.isEmpty) {
      return;
    }

    final normalizedUrl = AiProviderConfig.normalizeBaseUrl(rawUrl);
    final now = DateTime.now().millisecondsSinceEpoch;
    final credRef = 'cred_$now';

    if (apiKey.isNotEmpty) {
      await AiSecretStore.instance.saveApiKey(credRef, apiKey);
    }

    final newProvider = AiProviderConfig(
      id: 'provider_$now',
      name: name,
      baseUrl: normalizedUrl,
      credentialRef: credRef,
      models: const [
        AiModelConfig(
          modelId: 'deepseek-flash',
          protocol: AiProtocolType.completions,
          supportImages: true,
          supportAudio: false,
          contextLength: 1048576,
        ),
      ],
    );

    setState(() {
      _providers.add(newProvider);
      _selectedProviderIndex = _providers.length - 1;
      _newProviderNameController.clear();
      _newProviderApiKeyController.clear();
      _initTabController();
    });

    await _syncEditControllers();
    await _saveProviders();
  }

  Future<void> _deleteProvider(int index) async {
    if (index < 0 || index >= _providers.length) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.globalAiDeleteProvider),
        content: Text(l10n.globalAiConfirmDeleteProvider),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.globalAiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.globalAiDelete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final target = _providers[index];
    await AiSecretStore.instance.deleteApiKey(target.credentialRef);

    setState(() {
      _providers.removeAt(index);
      if (_selectedProviderIndex >= _providers.length) {
        _selectedProviderIndex = _providers.isEmpty ? 0 : _providers.length - 1;
      }
      _initTabController();
    });

    if (AiSettingsStore.activeProviderId == target.id) {
      AiSettingsStore.activeProviderId = _providers.isNotEmpty
          ? _providers.first.id
          : null;
      AiSettingsStore.activeModelId =
          _providers.isNotEmpty && _providers.first.models.isNotEmpty
          ? _providers.first.models.first.modelId
          : null;
    }

    await _syncEditControllers();
    await _saveProviders();
  }

  void _onModelUpdated(int modelIndex, AiModelConfig updatedModel) {
    if (_selectedProviderIndex < 0 ||
        _selectedProviderIndex >= _providers.length) {
      return;
    }

    final currentProvider = _providers[_selectedProviderIndex];
    final updatedModels = List<AiModelConfig>.from(currentProvider.models);

    if (modelIndex >= 0 && modelIndex < updatedModels.length) {
      updatedModels[modelIndex] = updatedModel;
      final updatedProvider = AiProviderConfig(
        id: currentProvider.id,
        name: currentProvider.name,
        baseUrl: currentProvider.baseUrl,
        credentialRef: currentProvider.credentialRef,
        models: updatedModels,
      );

      setState(() {
        _providers[_selectedProviderIndex] = updatedProvider;
      });
      _saveProviders();
    }
  }

  void _onModelDeleted(int modelIndex) {
    if (_selectedProviderIndex < 0 ||
        _selectedProviderIndex >= _providers.length) {
      return;
    }

    final currentProvider = _providers[_selectedProviderIndex];
    final updatedModels = List<AiModelConfig>.from(currentProvider.models);

    if (modelIndex >= 0 && modelIndex < updatedModels.length) {
      final removed = updatedModels.removeAt(modelIndex);
      final updatedProvider = AiProviderConfig(
        id: currentProvider.id,
        name: currentProvider.name,
        baseUrl: currentProvider.baseUrl,
        credentialRef: currentProvider.credentialRef,
        models: updatedModels,
      );

      setState(() {
        _providers[_selectedProviderIndex] = updatedProvider;
      });

      if (AiSettingsStore.activeModelId == removed.modelId) {
        AiSettingsStore.activeModelId = updatedModels.isNotEmpty
            ? updatedModels.first.modelId
            : null;
      }

      _saveProviders();
    }
  }

  void _addModelToCurrentProvider() {
    if (_selectedProviderIndex < 0 ||
        _selectedProviderIndex >= _providers.length) {
      return;
    }

    final currentProvider = _providers[_selectedProviderIndex];
    final updatedModels = List<AiModelConfig>.from(currentProvider.models);

    updatedModels.add(
      const AiModelConfig(
        modelId: 'deepseek-flash',
        protocol: AiProtocolType.completions,
        supportImages: true,
        supportAudio: false,
        contextLength: 1048576,
      ),
    );

    final updatedProvider = AiProviderConfig(
      id: currentProvider.id,
      name: currentProvider.name,
      baseUrl: currentProvider.baseUrl,
      credentialRef: currentProvider.credentialRef,
      models: updatedModels,
    );

    setState(() {
      _providers[_selectedProviderIndex] = updatedProvider;
    });
    _saveProviders();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.globalAiProviders,
                    style: theme.textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.globalAiClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAddProviderSection(l10n, theme),
                      const SizedBox(height: 20),
                      _buildModelSettingsSection(l10n, theme),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddProviderSection(AppLocalizations l10n, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.globalAiAddProvider,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newProviderNameController,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.globalAiProviderName,
              hintText: l10n.globalAiProviderNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newProviderUrlController,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.globalAiProviderBaseUrl,
              hintText: l10n.globalAiBaseUrlHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newProviderApiKeyController,
            obscureText: _obscureNewKey,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.globalAiProviderApiKey,
              hintText: l10n.globalAiApiKeyHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewKey ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscureNewKey = !_obscureNewKey);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.globalAiAddProvider),
              onPressed: _addNewProvider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSettingsSection(AppLocalizations l10n, ThemeData theme) {
    if (_providers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            l10n.globalAiNoProvidersPrompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final currentProvider = _providers[_selectedProviderIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.globalAiModelSettings,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // 标准 TabBar 切换已添加的供应商
        if (_tabController != null)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: _providers.map((p) => Tab(text: p.name)).toList(),
            ),
          ),
        const SizedBox(height: 16),

        // 当前供应商的编辑配置卡片（支持修改名称、API 地址、API Key）
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.25,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _editNameController,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.globalAiProviderName,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _saveCurrentProviderBasic(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _editUrlController,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.globalAiProviderBaseUrl,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _saveCurrentProviderBasic(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _editApiKeyController,
                obscureText: _obscureEditKey,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.globalAiProviderApiKey,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureEditKey ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscureEditKey = !_obscureEditKey);
                    },
                  ),
                ),
                onSubmitted: (_) => _saveCurrentProviderBasic(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _saveCurrentProviderBasic,
                  child: Text(l10n.globalAiSave),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 模型列表卡片
        if (currentProvider.models.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                l10n.globalAiNoModelsPrompt,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...List.generate(currentProvider.models.length, (mIdx) {
            final model = currentProvider.models[mIdx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModelBlockCard(
                key: ValueKey('${currentProvider.id}_model_$mIdx'),
                model: model,
                onUpdate: (updated) => _onModelUpdated(mIdx, updated),
                onDelete: () => _onModelDeleted(mIdx),
              ),
            );
          }),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.globalAiAddModel),
              onPressed: _addModelToCurrentProvider,
            ),
            TextButton.icon(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
              label: Text(
                l10n.globalAiDeleteProvider,
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () => _deleteProvider(_selectedProviderIndex),
            ),
          ],
        ),
      ],
    );
  }
}

/// 每一个模型的配置卡片块
class _ModelBlockCard extends StatefulWidget {
  final AiModelConfig model;
  final ValueChanged<AiModelConfig> onUpdate;
  final VoidCallback onDelete;

  const _ModelBlockCard({
    super.key,
    required this.model,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_ModelBlockCard> createState() => _ModelBlockCardState();
}

class _ModelBlockCardState extends State<_ModelBlockCard> {
  late final TextEditingController _idController;
  late final TextEditingController _contextLengthController;
  late final FocusNode _idFocusNode;
  late final FocusNode _contextFocusNode;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.model.modelId);
    _contextLengthController = TextEditingController(
      text: widget.model.contextLength.toString(),
    );
    _idFocusNode = FocusNode();
    _contextFocusNode = FocusNode();

    _idFocusNode.addListener(_onIdFocusChanged);
    _contextFocusNode.addListener(_onContextFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _ModelBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_idFocusNode.hasFocus && _idController.text != widget.model.modelId) {
      _idController.text = widget.model.modelId;
    }
    if (!_contextFocusNode.hasFocus &&
        _contextLengthController.text !=
            widget.model.contextLength.toString()) {
      _contextLengthController.text = widget.model.contextLength.toString();
    }
  }

  @override
  void dispose() {
    _idFocusNode.removeListener(_onIdFocusChanged);
    _contextFocusNode.removeListener(_onContextFocusChanged);
    _idFocusNode.dispose();
    _contextFocusNode.dispose();
    _idController.dispose();
    _contextLengthController.dispose();
    super.dispose();
  }

  void _onIdFocusChanged() {
    if (!_idFocusNode.hasFocus) {
      _submitId();
    }
  }

  void _onContextFocusChanged() {
    if (!_contextFocusNode.hasFocus) {
      _submitContextLength();
    }
  }

  void _submitId() {
    final newId = _idController.text.trim();
    if (newId.isNotEmpty && newId != widget.model.modelId) {
      widget.onUpdate(widget.model.copyWith(modelId: newId));
    }
  }

  void _submitContextLength() {
    final parsed = int.tryParse(_contextLengthController.text.trim());
    if (parsed != null && parsed > 0 && parsed != widget.model.contextLength) {
      widget.onUpdate(widget.model.copyWith(contextLength: parsed));
    }
  }

  void _setContextPreset(int length) {
    _contextLengthController.text = length.toString();
    widget.onUpdate(widget.model.copyWith(contextLength: length));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _idController,
                  focusNode: _idFocusNode,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: l10n.globalAiModelId,
                    hintText: 'deepseek-flash',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _submitId(),
                  onSubmitted: (_) => _submitId(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: l10n.globalAiDeleteModel,
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 协议类型：无边框简约下拉
          Row(
            children: [
              Text(
                l10n.globalAiProtocolType,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<AiProtocolType>(
                isDense: true,
                underline: const SizedBox.shrink(),
                value: widget.model.protocol,
                items: [
                  DropdownMenuItem(
                    value: AiProtocolType.completions,
                    child: Text(l10n.globalAiProtocolCompletions),
                  ),
                  DropdownMenuItem(
                    value: AiProtocolType.responses,
                    child: Text(l10n.globalAiProtocolResponses),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    widget.onUpdate(widget.model.copyWith(protocol: val));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 多模态能力：图片与音频同一行两个 Checkbox，无冒号
          Row(
            children: [
              Text(
                l10n.globalAiMultimodalSupport,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: widget.model.supportImages,
                    onChanged: (v) {
                      widget.onUpdate(
                        widget.model.copyWith(supportImages: v ?? false),
                      );
                    },
                  ),
                  Text(
                    l10n.globalAiSupportImages,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: widget.model.supportAudio,
                    onChanged: (v) {
                      widget.onUpdate(
                        widget.model.copyWith(supportAudio: v ?? false),
                      );
                    },
                  ),
                  Text(
                    l10n.globalAiSupportAudio,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 上下文长度：纯数字输入框 + 现代大模型常见预设（32K, 64K, 128K, 1M），无冒号
          Row(
            children: [
              Text(
                l10n.globalAiContextLength,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _contextLengthController,
                  focusNode: _contextFocusNode,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submitContextLength(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PresetChip(
                        label: '32K',
                        selected: widget.model.contextLength == 32768,
                        onTap: () => _setContextPreset(32768),
                      ),
                      const SizedBox(width: 4),
                      _PresetChip(
                        label: '64K',
                        selected: widget.model.contextLength == 65536,
                        onTap: () => _setContextPreset(65536),
                      ),
                      const SizedBox(width: 4),
                      _PresetChip(
                        label: '128K',
                        selected: widget.model.contextLength == 131072,
                        onTap: () => _setContextPreset(131072),
                      ),
                      const SizedBox(width: 4),
                      _PresetChip(
                        label: '1M',
                        selected: widget.model.contextLength == 1048576,
                        onTap: () => _setContextPreset(1048576),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
