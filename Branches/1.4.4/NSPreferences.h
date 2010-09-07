// Thanks file:///Developer/Examples/Python/PyObjC/ApplicationPlugins/Colloqui/Colloquy%20Plugin%20SDK/Headers/NSPreferences.h

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>
#import <AppKit/NSNibDeclarations.h>


// Private classes from the AppKit framework; used by Safari and Mail.

@class NSWindow;
@class NSMatrix;
@class NSBox;
@class NSButtonCell;
@class NSImage;
@class NSView;
@class NSMutableArray;
@class NSMutableDictionary;

@protocol NSPreferencesModule
- (BOOL) preferencesWindowShouldClose;
- (BOOL) moduleCanBeRemoved;
- (void) moduleWasInstalled;
- (void) moduleWillBeRemoved;
- (void) didChange;
- (void) initializeFromDefaults;
- (void) willBeDisplayed;
- (void) saveChanges;
- (BOOL) hasChangesPending;
- (NSImage *) imageForPreferenceNamed:(NSString *) name;
- (NSView *) viewForPreferenceNamed:(NSString *) name;
@end

@interface NSPreferences : NSObject {
	NSWindow *_preferencesPanel;
	NSBox *_preferenceBox;
	NSMatrix *_moduleMatrix;
	NSButtonCell *_okButton;
	NSButtonCell *_cancelButton;
	NSButtonCell *_applyButton;
	NSMutableArray *_preferenceTitles;
	NSMutableArray *_preferenceModules;
	NSMutableDictionary *_masterPreferenceViews;
	NSMutableDictionary *_currentSessionPreferenceViews;
	NSBox *_originalContentView;
	BOOL _isModal;
	float _constrainedWidth;
	id _currentModule;
	void *_reserved;
}
+ (id) sharedPreferences;
+ (void) setDefaultPreferencesClass:(Class) class;
+ (Class) defaultPreferencesClass;

- (id) init;
- (void) dealloc;
- (void) addPreferenceNamed:(NSString *) name owner:(id) owner;

- (NSSize) preferencesContentSize;

- (void) showPreferencesPanel;
- (void) showPreferencesPanelForOwner:(id) owner;
- (int) showModalPreferencesPanelForOwner:(id) owner;
- (int) showModalPreferencesPanel;

- (void) ok:(id) sender;
- (void) cancel:(id) sender;
- (void) apply:(id) sender;

- (NSString *) windowTitle;
- (BOOL) usesButtons;

@end

@interface NSPreferencesModule : NSObject <NSPreferencesModule> {
	IBOutlet NSBox *_preferencesView;
	NSSize _minSize;
	BOOL _hasChanges;
	void *_reserved;
}
+ (id) sharedInstance;
- (id) init;
- (NSString *) preferencesNibName;
- (void) setPreferencesView:(NSView *) view;
- (NSView *) viewForPreferenceNamed:(NSString *) name;
- (NSImage *) imageForPreferenceNamed:(NSString *) name;
- (NSString *) titleForIdentifier:(NSString *) identifier;
- (BOOL) hasChangesPending;
- (void) saveChanges;
- (void) willBeDisplayed;
- (void) initializeFromDefaults;
- (void) didChange;
- (NSSize) minSize;
- (void) setMinSize:(NSSize) size;
- (void) moduleWillBeRemoved;
- (void) moduleWasInstalled;
- (BOOL) moduleCanBeRemoved;
- (BOOL) preferencesWindowShouldClose;
- (BOOL) isResizable;
@end
