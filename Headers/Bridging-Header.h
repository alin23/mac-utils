#import <CoreGraphics/CoreGraphics.h>
#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>
#import <OSD/OSDManager.h>
#import <MonitorPanel/MPDisplayPreset.h>
#import <MonitorPanel/MPDisplay.h>
#import <MonitorPanel/MPDisplayMgr.h>
#import <MonitorPanel/MPDisplayMode.h>
#import <Cocoa/Cocoa.h>

@class BrightnessSystemClient;

@interface KeyboardBrightnessClient : NSObject
{
    BrightnessSystemClient *bsc;
}

- (void)registerNotificationForKeys:(id _Nonnull)arg1 keyboardID:(unsigned long long)arg2 block:(void)arg3;
- (void)unregisterKeyboardNotificationBlock;
- (BOOL)isAutoBrightnessEnabledForKeyboard:(unsigned long long)arg1;
- (BOOL)setIdleDimTime:(double)arg1 forKeyboard:(unsigned long long)arg2;
- (double)idleDimTimeForKeyboard:(unsigned long long)arg1;
- (BOOL)isKeyboardBuiltIn:(unsigned long long)arg1;
- (BOOL)isAmbientFeatureAvailableOnKeyboard:(unsigned long long)arg1;
- (BOOL)enableAutoBrightness:(BOOL)arg1 forKeyboard:(unsigned long long)arg2;
- (BOOL)setBrightness:(float)arg1 forKeyboard:(unsigned long long)arg2;
- (float)brightnessForKeyboard:(unsigned long long)arg1;
- (BOOL)isBacklightDimmedOnKeyboard:(unsigned long long)arg1;
- (BOOL)isBacklightSaturatedOnKeyboard:(unsigned long long)arg1;
- (BOOL)isBacklightSuppressedOnKeyboard:(unsigned long long)arg1;
- (NSArray<NSNumber *> *_Nullable)copyKeyboardBacklightIDs;
- (void)dealloc;
- (id _Nonnull)init;

@end

double CoreDisplay_Display_GetUserBrightness(CGDirectDisplayID display);
double CoreDisplay_Display_GetLinearBrightness(CGDirectDisplayID display);
double CoreDisplay_Display_GetDynamicLinearBrightness(CGDirectDisplayID display);

void CoreDisplay_Display_SetUserBrightness(CGDirectDisplayID display, double brightness);
void CoreDisplay_Display_SetLinearBrightness(CGDirectDisplayID display, double brightness);
void CoreDisplay_Display_SetDynamicLinearBrightness(CGDirectDisplayID display, double brightness);

void CoreDisplay_Display_SetAutoBrightnessIsEnabled(CGDirectDisplayID, bool);

CFDictionaryRef CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID);

int DisplayServicesGetLinearBrightness(CGDirectDisplayID display, float *brightness);
int DisplayServicesSetLinearBrightness(CGDirectDisplayID display, float brightness);
int DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightness);
int DisplayServicesSetBrightness(CGDirectDisplayID display, float brightness);
int DisplayServicesSetBrightnessSmooth(CGDirectDisplayID display, float brightness);
bool DisplayServicesCanChangeBrightness(CGDirectDisplayID display);
bool DisplayServicesHasAmbientLightCompensation(CGDirectDisplayID display);
bool DisplayServicesAmbientLightCompensationEnabled(CGDirectDisplayID display);
bool DisplayServicesIsSmartDisplay(CGDirectDisplayID display);
void DisplayServicesBrightnessChanged(CGDirectDisplayID display, double brightness);

extern int SLSMainConnectionID(void);
CGError SLSGetDisplayList(uint32_t maxDisplays, CGDirectDisplayID *activeDisplays, uint32_t *displayCount);
CGError SLSGetZoomParameters(int cid, CGPoint *origin, double *zoomFactor, bool *smoothed);

bool IsLidClosed(void)
{
    bool isClosed = false;
    io_registry_entry_t rootDomain;
    mach_port_t masterPort;
    CFTypeRef clamShellStateRef = NULL;

    IOReturn ioReturn = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (ioReturn != 0)
    {
        return false;
    }

    rootDomain = IORegistryEntryFromPath(masterPort, kIOPowerPlane ":/IOPowerConnection/IOPMrootDomain");

    clamShellStateRef = IORegistryEntryCreateCFProperty(rootDomain, CFSTR("AppleClamshellState"), kCFAllocatorDefault, 0);
    if (clamShellStateRef == NULL)
    {
        if (rootDomain)
        {
            IOObjectRelease(rootDomain);
            return false;
        }
    }

    if (CFBooleanGetValue((CFBooleanRef)(clamShellStateRef)) == true)
    {
        isClosed = true;
    }

    if (rootDomain)
    {
        IOObjectRelease(rootDomain);
    }

    if (clamShellStateRef)
    {
        CFRelease(clamShellStateRef);
    }

    return isClosed;
}

CGError CGSEnableHDR(CGDirectDisplayID display, bool enable, int, int) __attribute__((weak_import));
