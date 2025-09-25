import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const double _kMinimumWidth = 112;

const double _kDefaultHorizontalPadding = 12;

const double _kInputStartGap = 4;

class CustomDropdownMenu<TargetType> extends StatefulWidget {
  const CustomDropdownMenu.builder({
    super.key,
    required this.builder,
    this.enabled = true,
    this.width,
    this.menuHeight,
    this.leadingIcon,
    this.trailingIcon,
    this.showTrailingIcon = true,
    this.selectedTrailingIcon,
    this.enableFilter = false,
    this.enableSearch = true,
    this.textStyle,
    Object? inputDecorationTheme,
    this.menuStyle,
    this.controller,
    this.initialSelection,
    this.onSelected,
    this.focusNode,
    this.requestFocusOnTap,
    this.expandedInsets,
    this.filterCallback,
    this.searchCallback,
    this.alignmentOffset,
    required this.dropdownMenuEntries,
    this.closeBehavior = DropdownMenuCloseBehavior.all,
  }) : assert(
         filterCallback == null || enableFilter,
         'If filterCallback is provided, enableFilter must be true.',
       ),
       assert(
         inputDecorationTheme == null ||
             (inputDecorationTheme is InputDecorationTheme ||
                 inputDecorationTheme is InputDecorationThemeData),
         'inputDecorationTheme must be either InputDecorationTheme or InputDecorationThemeData.',
       ),
       _inputDecorationTheme = inputDecorationTheme;

  final bool enabled;

  final double? width;

  final double? menuHeight;

  final Widget? leadingIcon;

  final Widget? trailingIcon;

  final bool showTrailingIcon;

  final Widget? selectedTrailingIcon;

  final bool enableFilter;

  final bool enableSearch;

  final TextStyle? textStyle;

  InputDecorationThemeData? get inputDecorationTheme {
    if (_inputDecorationTheme == null) {
      return null;
    }
    return _inputDecorationTheme is InputDecorationTheme
        ? _inputDecorationTheme.data
        : _inputDecorationTheme as InputDecorationThemeData;
  }

  final Object? _inputDecorationTheme;

  final MenuStyle? menuStyle;

  final TextEditingController? controller;

  final TargetType? initialSelection;

  final ValueChanged<TargetType?>? onSelected;

  final FocusNode? focusNode;

  final bool? requestFocusOnTap;

  final List<DropdownMenuEntry<TargetType>> dropdownMenuEntries;

  final EdgeInsetsGeometry? expandedInsets;

  final FilterCallback<TargetType>? filterCallback;

  final SearchCallback<TargetType>? searchCallback;

  final Offset? alignmentOffset;

  final DropdownMenuCloseBehavior closeBehavior;

  final Widget Function(
    BuildContext context,
    CustomDropdownMenuProperties properties,
  )
  builder;

  @override
  State<CustomDropdownMenu<TargetType>> createState() =>
      _CustomDropdownMenuState<TargetType>();
}

class _CustomDropdownMenuState<TargetType>
    extends State<CustomDropdownMenu<TargetType>> {
  final GlobalKey _anchorKey = GlobalKey();
  final GlobalKey _leadingKey = GlobalKey();
  late List<GlobalKey> buttonItemKeys;
  final MenuController _controller = MenuController();
  bool _enableFilter = false;
  late bool _enableSearch;
  late List<DropdownMenuEntry<TargetType>> filteredEntries;
  List<Widget>? _initialMenu;
  int? currentHighlight;
  double? leadingPadding;
  bool _menuHasEnabledItem = false;
  TextEditingController? _localTextEditingController;
  TextEditingController get _effectiveTextEditingController =>
      widget.controller ??
      (_localTextEditingController ??= TextEditingController());
  final FocusNode _internalFocusNode = FocusNode();
  int? _selectedEntryIndex;
  late final void Function() _clearSelectedEntryIndex;

  @override
  void initState() {
    super.initState();
    _clearSelectedEntryIndex = () => _selectedEntryIndex = null;
    _effectiveTextEditingController.addListener(_clearSelectedEntryIndex);
    _enableSearch = widget.enableSearch;
    filteredEntries = widget.dropdownMenuEntries;
    buttonItemKeys = List<GlobalKey>.generate(
      filteredEntries.length,
      (int index) => GlobalKey(),
    );
    _menuHasEnabledItem = filteredEntries.any(
      (DropdownMenuEntry<TargetType> entry) => entry.enabled,
    );
    final index = filteredEntries.indexWhere(
      (DropdownMenuEntry<TargetType> entry) =>
          entry.value == widget.initialSelection,
    );
    if (index != -1) {
      _effectiveTextEditingController.value = TextEditingValue(
        text: filteredEntries[index].label,
        selection: TextSelection.collapsed(
          offset: filteredEntries[index].label.length,
        ),
      );
      _selectedEntryIndex = index;
    }
    refreshLeadingPadding();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_clearSelectedEntryIndex);
    _localTextEditingController?.dispose();
    _localTextEditingController = null;
    _internalFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CustomDropdownMenu<TargetType> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_clearSelectedEntryIndex);
      _localTextEditingController?.dispose();
      _localTextEditingController = null;
      _effectiveTextEditingController.addListener(_clearSelectedEntryIndex);
      _selectedEntryIndex = null;
    }
    if (oldWidget.enableFilter != widget.enableFilter) {
      if (!widget.enableFilter) {
        _enableFilter = false;
      }
    }
    if (oldWidget.enableSearch != widget.enableSearch) {
      if (!widget.enableSearch) {
        _enableSearch = widget.enableSearch;
        currentHighlight = null;
      }
    }
    if (oldWidget.dropdownMenuEntries != widget.dropdownMenuEntries) {
      currentHighlight = null;
      filteredEntries = widget.dropdownMenuEntries;
      buttonItemKeys = List<GlobalKey>.generate(
        filteredEntries.length,
        (int index) => GlobalKey(),
      );
      _menuHasEnabledItem = filteredEntries.any(
        (DropdownMenuEntry<TargetType> entry) => entry.enabled,
      );
      if (_selectedEntryIndex != null) {
        final oldSelectionValue =
            oldWidget.dropdownMenuEntries[_selectedEntryIndex!].value;
        final index = filteredEntries.indexWhere(
          (DropdownMenuEntry<TargetType> entry) =>
              entry.value == oldSelectionValue,
        );
        if (index != -1) {
          _effectiveTextEditingController.value = TextEditingValue(
            text: filteredEntries[index].label,
            selection: TextSelection.collapsed(
              offset: filteredEntries[index].label.length,
            ),
          );
          _selectedEntryIndex = index;
        } else {
          _selectedEntryIndex = null;
        }
      }
    }
    if (oldWidget.leadingIcon != widget.leadingIcon) {
      refreshLeadingPadding();
    }
    if (oldWidget.initialSelection != widget.initialSelection) {
      final index = filteredEntries.indexWhere(
        (DropdownMenuEntry<TargetType> entry) =>
            entry.value == widget.initialSelection,
      );
      if (index != -1) {
        _effectiveTextEditingController.value = TextEditingValue(
          text: filteredEntries[index].label,
          selection: TextSelection.collapsed(
            offset: filteredEntries[index].label.length,
          ),
        );
        _selectedEntryIndex = index;
      }
    }
  }

  bool canRequestFocus() {
    return widget.focusNode?.canRequestFocus ??
        widget.requestFocusOnTap ??
        switch (Theme.of(context).platform) {
          TargetPlatform.iOS ||
          TargetPlatform.android ||
          TargetPlatform.fuchsia => false,
          TargetPlatform.macOS ||
          TargetPlatform.linux ||
          TargetPlatform.windows => true,
        };
  }

  void refreshLeadingPadding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        leadingPadding = getWidth(_leadingKey);
      });
    }, debugLabel: 'DropdownMenu.refreshLeadingPadding');
  }

  void scrollToHighlight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final highlightContext = buttonItemKeys[currentHighlight!].currentContext;
      if (highlightContext != null) {
        Scrollable.of(
          highlightContext,
        ).position.ensureVisible(highlightContext.findRenderObject()!);
      }
    }, debugLabel: 'DropdownMenu.scrollToHighlight');
  }

  double? getWidth(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      final box = context.findRenderObject()! as RenderBox;
      return box.hasSize ? box.size.width : null;
    }
    return null;
  }

  List<DropdownMenuEntry<TargetType>> filter(
    List<DropdownMenuEntry<TargetType>> entries,
    TextEditingController textEditingController,
  ) {
    final filterText = textEditingController.text.toLowerCase();
    return entries
        .where(
          (DropdownMenuEntry<TargetType> entry) =>
              entry.label.toLowerCase().contains(filterText),
        )
        .toList();
  }

  bool _shouldUpdateCurrentHighlight(
    List<DropdownMenuEntry<TargetType>> entries,
  ) {
    final searchText = _effectiveTextEditingController.value.text.toLowerCase();
    if (searchText.isEmpty) {
      return true;
    }

    if (currentHighlight == null || currentHighlight! >= entries.length) {
      return true;
    }

    if (entries[currentHighlight!].label.toLowerCase().contains(searchText)) {
      return false;
    }

    return true;
  }

  int? search(
    List<DropdownMenuEntry<TargetType>> entries,
    TextEditingController textEditingController,
  ) {
    final searchText = textEditingController.value.text.toLowerCase();
    if (searchText.isEmpty) {
      return null;
    }

    final index = entries.indexWhere(
      (DropdownMenuEntry<TargetType> entry) =>
          entry.label.toLowerCase().contains(searchText),
    );

    return index != -1 ? index : null;
  }

  List<Widget> _buildButtons(
    List<DropdownMenuEntry<TargetType>> filteredEntries,
    TextDirection textDirection, {
    int? focusedIndex,
    bool enableScrollToHighlight = true,
    bool excludeSemantics = false,
    bool? useMaterial3,
  }) {
    final effectiveInputStartGap = useMaterial3 ?? false
        ? _kInputStartGap
        : 0.0;
    final result = <Widget>[];
    for (var i = 0; i < filteredEntries.length; i++) {
      final entry = filteredEntries[i];

      final padding = entry.leadingIcon == null
          ? (leadingPadding ?? _kDefaultHorizontalPadding)
          : _kDefaultHorizontalPadding;
      var effectiveStyle =
          entry.style ??
          MenuItemButton.styleFrom(
            padding: EdgeInsetsDirectional.only(
              start: padding,
              end: _kDefaultHorizontalPadding,
            ),
          );

      final themeStyle = MenuButtonTheme.of(context).style;

      final effectiveForegroundColor =
          entry.style?.foregroundColor ?? themeStyle?.foregroundColor;
      final effectiveIconColor =
          entry.style?.iconColor ?? themeStyle?.iconColor;
      final effectiveOverlayColor =
          entry.style?.overlayColor ?? themeStyle?.overlayColor;
      final effectiveBackgroundColor =
          entry.style?.backgroundColor ?? themeStyle?.backgroundColor;

      if (entry.enabled && i == focusedIndex) {
        final defaultStyle = const MenuItemButton().defaultStyleOf(context);

        Color? resolveFocusedColor(
          WidgetStateProperty<Color?>? colorStateProperty,
        ) {
          return colorStateProperty?.resolve(<WidgetState>{
            WidgetState.focused,
          });
        }

        final focusedForegroundColor = resolveFocusedColor(
          effectiveForegroundColor ?? defaultStyle.foregroundColor!,
        )!;
        final focusedIconColor = resolveFocusedColor(
          effectiveIconColor ?? defaultStyle.iconColor!,
        )!;
        final focusedOverlayColor = resolveFocusedColor(
          effectiveOverlayColor ?? defaultStyle.overlayColor!,
        )!;

        final focusedBackgroundColor =
            resolveFocusedColor(effectiveBackgroundColor) ??
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);

        effectiveStyle = effectiveStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll<Color>(
            focusedBackgroundColor,
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(
            focusedForegroundColor,
          ),
          iconColor: WidgetStatePropertyAll<Color>(focusedIconColor),
          overlayColor: WidgetStatePropertyAll<Color>(focusedOverlayColor),
        );
      } else {
        effectiveStyle = effectiveStyle.copyWith(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveForegroundColor,
          iconColor: effectiveIconColor,
          overlayColor: effectiveOverlayColor,
        );
      }

      var label = entry.labelWidget ?? Text(entry.label);
      if (widget.width != null) {
        final horizontalPadding =
            padding + _kDefaultHorizontalPadding + effectiveInputStartGap;
        label = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.width! - horizontalPadding,
          ),
          child: label,
        );
      }

      final Widget menuItemButton = ExcludeSemantics(
        excluding: excludeSemantics,
        child: MenuItemButton(
          key: enableScrollToHighlight ? buttonItemKeys[i] : null,
          style: effectiveStyle,
          leadingIcon: entry.leadingIcon,
          trailingIcon: entry.trailingIcon,
          closeOnActivate:
              widget.closeBehavior == DropdownMenuCloseBehavior.all,
          onPressed: entry.enabled && widget.enabled
              ? () {
                  if (!mounted) {
                    widget.controller?.value = TextEditingValue(
                      text: entry.label,
                      selection: TextSelection.collapsed(
                        offset: entry.label.length,
                      ),
                    );
                    widget.onSelected?.call(entry.value);
                    return;
                  }
                  _effectiveTextEditingController.value = TextEditingValue(
                    text: entry.label,
                    selection: TextSelection.collapsed(
                      offset: entry.label.length,
                    ),
                  );
                  _selectedEntryIndex = i;
                  currentHighlight = widget.enableSearch ? i : null;
                  widget.onSelected?.call(entry.value);
                  _enableFilter = false;
                  if (widget.closeBehavior == DropdownMenuCloseBehavior.self) {
                    _controller.close();
                  }
                }
              : null,
          requestFocusOnHover: false,

          child: Padding(
            padding: EdgeInsetsDirectional.only(start: effectiveInputStartGap),
            child: label,
          ),
        ),
      );
      result.add(menuItemButton);
    }

    return result;
  }

  void handleUpKeyInvoke(_ArrowUpIntent _) {
    setState(() {
      if (!widget.enabled || !_menuHasEnabledItem || !_controller.isOpen) {
        return;
      }
      _enableFilter = false;
      _enableSearch = false;
      currentHighlight ??= 0;
      currentHighlight = (currentHighlight! - 1) % filteredEntries.length;
      while (!filteredEntries[currentHighlight!].enabled) {
        currentHighlight = (currentHighlight! - 1) % filteredEntries.length;
      }
      final currentLabel = filteredEntries[currentHighlight!].label;
      _effectiveTextEditingController.value = TextEditingValue(
        text: currentLabel,
        selection: TextSelection.collapsed(offset: currentLabel.length),
      );
    });
  }

  void handleDownKeyInvoke(_ArrowDownIntent _) {
    setState(() {
      if (!widget.enabled || !_menuHasEnabledItem || !_controller.isOpen) {
        return;
      }
      _enableFilter = false;
      _enableSearch = false;
      currentHighlight ??= -1;
      currentHighlight = (currentHighlight! + 1) % filteredEntries.length;
      while (!filteredEntries[currentHighlight!].enabled) {
        currentHighlight = (currentHighlight! + 1) % filteredEntries.length;
      }
      final currentLabel = filteredEntries[currentHighlight!].label;
      _effectiveTextEditingController.value = TextEditingValue(
        text: currentLabel,
        selection: TextSelection.collapsed(offset: currentLabel.length),
      );
    });
  }

  void handlePressed(
    MenuController controller, {
    bool focusForKeyboard = true,
  }) {
    if (controller.isOpen) {
      currentHighlight = null;
      controller.close();
    } else {
      filteredEntries = widget.dropdownMenuEntries;

      if (_effectiveTextEditingController.text.isNotEmpty) {
        _enableFilter = false;
      }
      controller.open();
      if (focusForKeyboard) {
        _internalFocusNode.requestFocus();
      }
    }
    setState(() {});
  }

  void _handleEditingComplete() {
    if (currentHighlight != null) {
      final entry = filteredEntries[currentHighlight!];
      if (entry.enabled) {
        _effectiveTextEditingController.value = TextEditingValue(
          text: entry.label,
          selection: TextSelection.collapsed(offset: entry.label.length),
        );
        _selectedEntryIndex = currentHighlight;
        widget.onSelected?.call(entry.value);
      }
    } else {
      if (_controller.isOpen) {
        widget.onSelected?.call(null);
      }
    }
    if (!widget.enableSearch) {
      currentHighlight = null;
    }
    _controller.close();
  }

  @override
  Widget build(BuildContext context) {
    final useMaterial3 = Theme.of(context).useMaterial3;
    final textDirection = Directionality.of(context);
    _initialMenu ??= _buildButtons(
      widget.dropdownMenuEntries,
      textDirection,
      enableScrollToHighlight: false,

      excludeSemantics: true,
      useMaterial3: useMaterial3,
    );
    final theme = DropdownMenuTheme.of(context);
    final DropdownMenuThemeData defaults = _DropdownMenuDefaultsM3(context);

    if (_enableFilter) {
      filteredEntries =
          widget.filterCallback?.call(
            filteredEntries,
            _effectiveTextEditingController.text,
          ) ??
          filter(widget.dropdownMenuEntries, _effectiveTextEditingController);
    }
    _menuHasEnabledItem = filteredEntries.any(
      (DropdownMenuEntry<TargetType> entry) => entry.enabled,
    );

    if (_enableSearch) {
      if (widget.searchCallback != null) {
        currentHighlight = widget.searchCallback!(
          filteredEntries,
          _effectiveTextEditingController.text,
        );
      } else {
        final shouldUpdateCurrentHighlight = _shouldUpdateCurrentHighlight(
          filteredEntries,
        );
        if (shouldUpdateCurrentHighlight) {
          currentHighlight = search(
            filteredEntries,
            _effectiveTextEditingController,
          );
        }
      }
      if (currentHighlight != null) {
        scrollToHighlight();
      }
    }

    final menu = _buildButtons(
      filteredEntries,
      textDirection,
      focusedIndex: currentHighlight,
      useMaterial3: useMaterial3,
    );

    final baseTextStyle =
        widget.textStyle ?? theme.textStyle ?? defaults.textStyle;
    final disabledColor = theme.disabledColor ?? defaults.disabledColor;
    final effectiveTextStyle = widget.enabled
        ? baseTextStyle
        : baseTextStyle?.copyWith(color: disabledColor) ??
              TextStyle(color: disabledColor);

    MenuStyle? effectiveMenuStyle =
        widget.menuStyle ?? theme.menuStyle ?? defaults.menuStyle!;

    final anchorWidth = getWidth(_anchorKey);
    if (widget.width != null) {
      effectiveMenuStyle = effectiveMenuStyle.copyWith(
        minimumSize: WidgetStateProperty.resolveWith<Size?>((
          Set<WidgetState> states,
        ) {
          final effectiveMaximumWidth = effectiveMenuStyle!.maximumSize
              ?.resolve(states)
              ?.width;
          return Size(math.min(widget.width!, effectiveMaximumWidth ?? 0.0), 0);
        }),
      );
    } else if (anchorWidth != null) {
      effectiveMenuStyle = effectiveMenuStyle.copyWith(
        minimumSize: WidgetStateProperty.resolveWith<Size?>((
          Set<WidgetState> states,
        ) {
          final effectiveMaximumWidth = effectiveMenuStyle!.maximumSize
              ?.resolve(states)
              ?.width;
          return Size(math.min(anchorWidth, effectiveMaximumWidth ?? 0.0), 0);
        }),
      );
    }

    if (widget.menuHeight != null) {
      effectiveMenuStyle = effectiveMenuStyle.copyWith(
        maximumSize: WidgetStatePropertyAll<Size>(
          Size(double.infinity, widget.menuHeight!),
        ),
      );
    }
    final effectiveInputDecorationTheme =
        widget.inputDecorationTheme ??
        theme.inputDecorationTheme ??
        defaults.inputDecorationTheme!;

    final MouseCursor? effectiveMouseCursor = switch (widget.enabled) {
      true =>
        canRequestFocus() ? SystemMouseCursors.text : SystemMouseCursors.click,
      false => null,
    };

    Widget menuAnchor = MenuAnchor(
      style: effectiveMenuStyle,
      alignmentOffset: widget.alignmentOffset,
      controller: _controller,
      menuChildren: menu,
      crossAxisUnconstrained: false,
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            assert(
              _initialMenu != null,
              'Initial menu must not be null. Did you forget to initialize it?',
            );
            final isCollapsed =
                widget.inputDecorationTheme?.isCollapsed ?? false;
            final Widget trailingButton = widget.showTrailingIcon
                ? Padding(
                    padding: isCollapsed
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(4),
                    child: IconButton(
                      isSelected: controller.isOpen,
                      constraints:
                          widget.inputDecorationTheme?.suffixIconConstraints,
                      padding: isCollapsed ? EdgeInsets.zero : null,
                      icon:
                          widget.trailingIcon ??
                          const Icon(Icons.arrow_drop_down),
                      selectedIcon:
                          widget.selectedTrailingIcon ??
                          const Icon(Icons.arrow_drop_up),
                      onPressed: !widget.enabled
                          ? null
                          : () {
                              handlePressed(controller);
                            },
                    ),
                  )
                : const SizedBox.shrink();

            final Widget leadingButton = Padding(
              padding: const EdgeInsets.all(8),
              child: widget.leadingIcon ?? const SizedBox.shrink(),
            );

            final properties = CustomDropdownMenuProperties(
              enabled: widget.enabled,
              focusNode: widget.focusNode,
              mouseCursor: effectiveMouseCursor,
              canRequestFocus: canRequestFocus(),
              enableInteractiveSelection: canRequestFocus(),
              readOnly: !canRequestFocus(),
              style: effectiveTextStyle,
              controller: _effectiveTextEditingController,
              onEditingComplete: _handleEditingComplete,
              onTap: !widget.enabled
                  ? null
                  : () {
                      handlePressed(
                        controller,
                        focusForKeyboard: !canRequestFocus(),
                      );
                    },
              onChanged: (_) {
                controller.open();
                setState(() {
                  filteredEntries = widget.dropdownMenuEntries;
                  _enableFilter = widget.enableFilter;
                  _enableSearch = widget.enableSearch;
                });
              },
              prefixIcon: widget.leadingIcon != null
                  ? SizedBox(key: _leadingKey, child: widget.leadingIcon)
                  : null,
              suffixIcon: widget.showTrailingIcon ? trailingButton : null,
              effectiveInputDecorationTheme: effectiveInputDecorationTheme,
            );

            final Widget textField = widget.builder(context, properties);

            final body = widget.expandedInsets != null
                ? textField
                : _DropdownMenuBody(
                    width: widget.width,
                    children: <Widget>[
                      textField,
                      ..._initialMenu!.map(
                        (Widget item) => ExcludeFocus(
                          excluding: !controller.isOpen,
                          child: item,
                        ),
                      ),

                      trailingButton,
                      leadingButton,
                    ],
                  );

            return Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(
                  LogicalKeyboardKey.arrowLeft,
                ): ExtendSelectionByCharacterIntent(
                  forward: false,
                  collapseSelection: true,
                ),
                SingleActivator(
                  LogicalKeyboardKey.arrowRight,
                ): ExtendSelectionByCharacterIntent(
                  forward: true,
                  collapseSelection: true,
                ),
                SingleActivator(LogicalKeyboardKey.arrowUp): _ArrowUpIntent(),
                SingleActivator(LogicalKeyboardKey.arrowDown):
                    _ArrowDownIntent(),
              },
              child: body,
            );
          },
    );

    if (widget.expandedInsets case final EdgeInsetsGeometry padding) {
      menuAnchor = Padding(
        padding: padding.clamp(
          EdgeInsets.zero,
          const EdgeInsets.only(
            left: double.infinity,
            right: double.infinity,
          ).add(
            const EdgeInsetsDirectional.only(
              end: double.infinity,
              start: double.infinity,
            ),
          ),
        ),
        child: menuAnchor,
      );
    }

    menuAnchor = Align(
      alignment: AlignmentDirectional.topStart,
      widthFactor: 1,
      heightFactor: 1,
      child: menuAnchor,
    );

    return Actions(
      actions: <Type, Action<Intent>>{
        _ArrowUpIntent: CallbackAction<_ArrowUpIntent>(
          onInvoke: handleUpKeyInvoke,
        ),
        _ArrowDownIntent: CallbackAction<_ArrowDownIntent>(
          onInvoke: handleDownKeyInvoke,
        ),
        _EnterIntent: CallbackAction<_EnterIntent>(
          onInvoke: (_) => _handleEditingComplete(),
        ),
      },
      child: Stack(
        children: <Widget>[
          Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.arrowUp): _ArrowUpIntent(),
              SingleActivator(LogicalKeyboardKey.arrowDown): _ArrowDownIntent(),
              SingleActivator(LogicalKeyboardKey.enter): _EnterIntent(),
            },
            child: Focus(
              focusNode: _internalFocusNode,
              skipTraversal: true,
              child: const SizedBox.shrink(),
            ),
          ),
          menuAnchor,
        ],
      ),
    );
  }
}

class _ArrowUpIntent extends Intent {
  const _ArrowUpIntent();
}

class _ArrowDownIntent extends Intent {
  const _ArrowDownIntent();
}

class _EnterIntent extends Intent {
  const _EnterIntent();
}

class _DropdownMenuBody extends MultiChildRenderObjectWidget {
  const _DropdownMenuBody({super.children, this.width});

  final double? width;

  @override
  _RenderDropdownMenuBody createRenderObject(BuildContext context) {
    return _RenderDropdownMenuBody(width: width);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDropdownMenuBody renderObject,
  ) {
    renderObject.width = width;
  }
}

class _DropdownMenuBodyParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDropdownMenuBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DropdownMenuBodyParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _DropdownMenuBodyParentData
        > {
  _RenderDropdownMenuBody({double? width}) : _width = width;

  double? get width => _width;
  double? _width;
  set width(double? value) {
    if (_width == value) {
      return;
    }
    _width = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DropdownMenuBodyParentData) {
      child.parentData = _DropdownMenuBodyParentData();
    }
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    double maxWidth = 0;
    double? maxHeight;
    var child = firstChild;

    final intrinsicWidth = width ?? getMaxIntrinsicWidth(constraints.maxHeight);
    final double widthConstraint = math.min(
      intrinsicWidth,
      constraints.maxWidth,
    );
    final innerConstraints = BoxConstraints(
      maxWidth: widthConstraint,
      maxHeight: getMaxIntrinsicHeight(widthConstraint),
    );
    while (child != null) {
      if (child == firstChild) {
        child.layout(innerConstraints, parentUsesSize: true);
        maxHeight ??= child.size.height;
        final childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        assert(
          child.parentData == childParentData,
          'Parent data for child is not _DropdownMenuBodyParentData as expected.',
        );
        child = childParentData.nextSibling;
        continue;
      }
      child.layout(innerConstraints, parentUsesSize: true);
      final childParentData = (child.parentData! as _DropdownMenuBodyParentData)
        ..offset = Offset.zero;
      maxWidth = math.max(maxWidth, child.size.width);
      maxHeight ??= child.size.height;
      assert(
        child.parentData == childParentData,
        'Parent data for child is not _DropdownMenuBodyParentData as expected.',
      );
      child = childParentData.nextSibling;
    }

    assert(
      maxHeight != null,
      'maxHeight must not be null after laying out children in _RenderDropdownMenuBody.performLayout',
    );
    maxWidth = math.max(_kMinimumWidth, maxWidth);
    size = constraints.constrain(Size(width ?? maxWidth, maxHeight!));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = firstChild;
    if (child != null) {
      final childParentData = child.parentData! as _DropdownMenuBodyParentData;
      context.paintChild(child, offset + childParentData.offset);
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final constraints = this.constraints;
    double maxWidth = 0;
    double? maxHeight;
    var child = firstChild;
    final intrinsicWidth = width ?? getMaxIntrinsicWidth(constraints.maxHeight);
    final double widthConstraint = math.min(
      intrinsicWidth,
      constraints.maxWidth,
    );
    final innerConstraints = BoxConstraints(
      maxWidth: widthConstraint,
      maxHeight: getMaxIntrinsicHeight(widthConstraint),
    );

    while (child != null) {
      if (child == firstChild) {
        final childSize = child.getDryLayout(innerConstraints);
        maxHeight ??= childSize.height;
        final childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        assert(
          child.parentData == childParentData,
          'Parent data for child is not _DropdownMenuBodyParentData as expected.',
        );
        child = childParentData.nextSibling;
        continue;
      }
      final childSize = child.getDryLayout(innerConstraints);
      final childParentData = (child.parentData! as _DropdownMenuBodyParentData)
        ..offset = Offset.zero;
      maxWidth = math.max(maxWidth, childSize.width);
      maxHeight ??= childSize.height;
      assert(
        child.parentData == childParentData,
        'Parent data for child is not _DropdownMenuBodyParentData as expected.',
      );
      child = childParentData.nextSibling;
    }

    assert(
      maxHeight != null,
      'maxHeight must not be null after laying out children in _RenderDropdownMenuBody.computeDryLayout',
    );
    maxWidth = math.max(_kMinimumWidth, maxWidth);
    return constraints.constrain(Size(width ?? maxWidth, maxHeight!));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var child = firstChild;
    double width = 0;
    while (child != null) {
      if (child == firstChild) {
        final childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        child = childParentData.nextSibling;
        continue;
      }
      final maxIntrinsicWidth = child.getMinIntrinsicWidth(height);

      if (child == lastChild) {
        width += maxIntrinsicWidth;
      }

      if (child == childBefore(lastChild!)) {
        width += maxIntrinsicWidth;
      }
      width = math.max(width, maxIntrinsicWidth);
      final childParentData = child.parentData! as _DropdownMenuBodyParentData;
      child = childParentData.nextSibling;
    }

    return math.max(width, _kMinimumWidth);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var child = firstChild;
    double width = 0;
    while (child != null) {
      if (child == firstChild) {
        final childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        child = childParentData.nextSibling;
        continue;
      }
      final maxIntrinsicWidth = child.getMaxIntrinsicWidth(height);

      if (child == lastChild) {
        width += maxIntrinsicWidth;
      }

      if (child == childBefore(lastChild!)) {
        width += maxIntrinsicWidth;
      }
      width = math.max(width, maxIntrinsicWidth);
      final childParentData = child.parentData! as _DropdownMenuBodyParentData;
      child = childParentData.nextSibling;
    }

    return math.max(width, _kMinimumWidth);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final child = firstChild;
    double width = 0;
    if (child != null) {
      width = math.max(width, child.getMinIntrinsicHeight(width));
    }
    return width;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final child = firstChild;
    double width = 0;
    if (child != null) {
      width = math.max(width, child.getMaxIntrinsicHeight(width));
    }
    return width;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = firstChild;
    if (child != null) {
      final childParentData = child.parentData! as _DropdownMenuBodyParentData;
      final isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(
            transformed == position - childParentData.offset,
            'Transformed position should equal position minus child offset in hitTestChildren.',
          );
          return child.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitChildren((RenderObject renderObjectChild) {
      final child = renderObjectChild as RenderBox;
      if (child == firstChild) {
        visitor(renderObjectChild);
      }
    });
  }
}

class _DropdownMenuDefaultsM3 extends DropdownMenuThemeData {
  _DropdownMenuDefaultsM3(this.context)
    : super(
        disabledColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.38),
      );

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);

  @override
  TextStyle? get textStyle => _theme.textTheme.bodyLarge;

  @override
  MenuStyle get menuStyle {
    return const MenuStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(_kMinimumWidth, 0)),
      maximumSize: WidgetStatePropertyAll<Size>(Size.infinite),
      visualDensity: VisualDensity.standard,
    );
  }

  @override
  InputDecorationThemeData get inputDecorationTheme {
    return const InputDecorationThemeData(border: OutlineInputBorder());
  }
}

class CustomDropdownMenuProperties {
  CustomDropdownMenuProperties({
    required this.mouseCursor,
    required this.canRequestFocus,
    required this.enableInteractiveSelection,
    required this.readOnly,
    required this.style,
    required this.controller,
    required this.onEditingComplete,
    required this.onTap,
    required this.onChanged,
    required this.effectiveInputDecorationTheme,
    required this.prefixIcon,
    required this.suffixIcon,
    required this.enabled,
    required this.focusNode,
  });

  final MouseCursor? mouseCursor;
  final bool canRequestFocus;
  final bool enableInteractiveSelection;
  final bool readOnly;
  final TextStyle? style;
  final TextEditingController controller;
  final void Function()? onEditingComplete;
  final void Function()? onTap;
  final void Function(String value)? onChanged;
  final InputDecorationThemeData effectiveInputDecorationTheme;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final FocusNode? focusNode;
}
