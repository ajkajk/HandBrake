/*  HBAddPresetController.m

 This file is part of the HandBrake source code.
 Homepage: <http://handbrake.fr/>.
 It may be used under the terms of the GNU General Public License. */

#import "HBAddPresetController.h"

#import "HBAddCategoryController.h"

#import "HBAudioDefaultsController.h"
#import "HBSubtitlesDefaultsController.h"

#import "HBPresetsManager.h"
#import "HBPreset.h"

@import HandBrakeKit;

typedef NS_ENUM(NSUInteger, HBAddPresetControllerMode) {
    HBAddPresetControllerModeNone,
    HBAddPresetControllerModeCustom,
    HBAddPresetControllerModeSourceMaximum,
};

@interface HBAddPresetController ()

@property (unsafe_unretained) IBOutlet NSTextField *name;
@property (unsafe_unretained) IBOutlet NSTextField *desc;

@property (unsafe_unretained) IBOutlet NSPopUpButton *categories;

@property (unsafe_unretained) IBOutlet NSPopUpButton *picSettingsPopUp;
@property (unsafe_unretained) IBOutlet NSTextField *picWidth;
@property (unsafe_unretained) IBOutlet NSTextField *picHeight;
@property (unsafe_unretained) IBOutlet NSBox *picWidthHeightBox;

@property (nonatomic, strong) HBPreset *preset;
@property (nonatomic, strong) HBMutablePreset *mutablePreset;

@property (nonatomic, strong) HBPreset *selectedCategory;

@property (nonatomic, strong) HBPresetsManager *manager;

@property (nonatomic) int width;
@property (nonatomic) int height;

@property (nonatomic) BOOL defaultToCustom;

@property (nonatomic, readwrite, strong) NSWindowController *defaultsController;


@end

@implementation HBAddPresetController

- (instancetype)initWithPreset:(HBPreset *)preset presetManager:(HBPresetsManager *)manager customWidth:(int)customWidth customHeight:(int)customHeight defaultToCustom:(BOOL)defaultToCustom
{
    self = [super initWithWindowNibName:@"AddPreset"];
    if (self)
    {
        NSParameterAssert(preset);
        _mutablePreset = [preset mutableCopy];
        _manager = manager;
        _width = customWidth;
        _height = customHeight;
        _defaultToCustom = defaultToCustom;
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    // Build the categories menu, and select the first
    [self buildCategoriesMenu];
    if ([self.categories selectItemWithTag:2] == NO)
    {
        HBPreset *category = [[HBPreset alloc] initWithCategoryName:@"My Presets" builtIn:NO];
        [self.manager addPreset:category];
        NSMenuItem *item = [self buildMenuItemWithCategory:category];
        [self.categories.menu insertItem:item atIndex:2];
        [self.categories selectItemWithTag:2];
    }

    // Populate the preset picture settings popup.
    // Use [NSMenuItem tag] to store preset values for each option.

    // Default to Source Maximum
    HBAddPresetControllerMode mode = HBAddPresetControllerModeSourceMaximum;

    [self.picSettingsPopUp addItemWithTitle:NSLocalizedString(@"None", nil)];
    [[self.picSettingsPopUp lastItem] setTag:HBAddPresetControllerModeNone];

    [self.picSettingsPopUp addItemWithTitle:NSLocalizedString(@"Custom", nil)];
    [[self.picSettingsPopUp lastItem] setTag:HBAddPresetControllerModeCustom];

    if (self.defaultToCustom)
    {
        mode = HBAddPresetControllerModeCustom;
    }
    [self.picSettingsPopUp addItemWithTitle:NSLocalizedString(@"Source Maximum", nil)];
    [[self.picSettingsPopUp lastItem] setTag:HBAddPresetControllerModeSourceMaximum];


    [self.picSettingsPopUp selectItemWithTag:mode];

    // Initialize custom height and width settings to current values
    [self.picWidth setIntValue:self.width];
    [self.picHeight setIntValue:self.height];
    [self addPresetPicDropdownChanged:nil];
}

/**
 *  Adds the presets list to the menu.
 */
- (void)buildCategoriesMenu
{
    for (HBPreset *preset in self.manager.root.children)
    {
        if (preset.isBuiltIn == NO && preset.isLeaf == NO)
        {
            [self.categories.menu addItem:[self buildMenuItemWithCategory:preset]];
        }
    }
}

- (NSMenuItem *)buildMenuItemWithCategory:(HBPreset *)preset
{
    NSMenuItem *item = [[NSMenuItem alloc] init];
    item.title = preset.name;
    item.toolTip = preset.presetDescription;
    item.tag = 2;

    item.action = @selector(selectCategoryFromMenu:);
    item.representedObject = preset;

    return item;
}

- (IBAction)showNewCategoryWindow:(id)sender
{
    HBAddCategoryController *addCategoryController = [[HBAddCategoryController alloc] initWithPresetManager:self.manager];

    [NSApp beginSheet:addCategoryController.window modalForWindow:self.window modalDelegate:self didEndSelector:@selector(categorySheetDidEnd:returnCode:contextInfo:) contextInfo:(void *)CFBridgingRetain(addCategoryController)];
}

- (void)categorySheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    HBAddCategoryController *addCategoryController = (HBAddCategoryController *)CFBridgingRelease(contextInfo);

    if (returnCode == NSModalResponseOK)
    {
        NSMenuItem *item = [self buildMenuItemWithCategory:addCategoryController.category];
        [self.categories.menu insertItem:item atIndex:2];
    }

    [self.categories selectItemWithTag:2];
    [self selectCategoryFromMenu:self.categories.selectedItem];
}

- (IBAction)selectCategoryFromMenu:(NSMenuItem *)sender
{
    self.selectedCategory = sender.representedObject;
}

- (IBAction)addPresetPicDropdownChanged:(id)sender
{
    if (self.picSettingsPopUp.selectedItem.tag == HBAddPresetControllerModeCustom)
    {
        self.picWidthHeightBox.hidden = NO;
    }
    else
    {
        self.picWidthHeightBox.hidden = YES;
    }
}

- (IBAction)showAudioSettingsSheet:(id)sender
{
    HBAudioDefaults *defaults = [[HBAudioDefaults alloc] init];
    [defaults applyPreset:self.mutablePreset];

    self.defaultsController = [[HBAudioDefaultsController alloc] initWithSettings:defaults];

    [NSApp beginSheet:self.defaultsController.window
       modalForWindow:self.window
        modalDelegate:self
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
          contextInfo:(void *)CFBridgingRetain(defaults)];
}

- (IBAction)showSubtitlesSettingsSheet:(id)sender
{
    HBSubtitlesDefaults *defaults = [[HBSubtitlesDefaults alloc] init];
    [defaults applyPreset:self.mutablePreset];

    self.defaultsController = [[HBSubtitlesDefaultsController alloc] initWithSettings:defaults];

    [NSApp beginSheet:self.defaultsController.window
       modalForWindow:self.window
        modalDelegate:self
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
          contextInfo:(void *)CFBridgingRetain(defaults)];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    id defaults = (id)CFBridgingRelease(contextInfo);

    if (returnCode == NSModalResponseOK)
    {
        [defaults writeToPreset:self.mutablePreset];
    }
    self.defaultsController = nil;
}

- (IBAction)add:(id)sender
{
    if (self.name.stringValue.length == 0)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:NSLocalizedString(@"The preset name cannot be empty.", @"")];
        [alert setInformativeText:NSLocalizedString(@"Please enter a name.", @"")];
        [alert runModal];
    }
    else
    {
        HBMutablePreset *newPreset = self.mutablePreset;

        newPreset.name = self.name.stringValue;
        newPreset.presetDescription = self.desc.stringValue;

        if (self.picSettingsPopUp.selectedTag == HBAddPresetControllerModeSourceMaximum)
        {
            newPreset[@"PictureWidth"] = @0;
            newPreset[@"PictureHeight"] = @0;
        }
        else
        {
            // Get the user set picture size
            newPreset[@"PictureWidth"] = @(self.picWidth.integerValue);
            newPreset[@"PictureHeight"] = @(self.picHeight.integerValue);
        }

        //Get the whether or not to apply pic Size and Cropping (includes Anamorphic)
        newPreset[@"UsesPictureSettings"] = @(self.picSettingsPopUp.selectedTag);

        // Always use Picture Filter settings for the preset
        newPreset[@"UsesPictureFilters"] = @YES;

        [newPreset cleanUp];

        self.preset = [newPreset copy];
        [self.selectedCategory insertObject:self.preset inChildrenAtIndex:0];

        [self.window orderOut:nil];
        [NSApp endSheet:self.window returnCode:NSModalResponseContinue];
    }
}

- (IBAction)cancel:(id)sender
{
    [self.window orderOut:nil];
    [NSApp endSheet:self.window returnCode:NSModalResponseAbort];
}

- (IBAction)openUserGuide:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL
                                            URLWithString:@"https://handbrake.fr/docs/en/latest/advanced/custom-presets.html"]];
}

@end
