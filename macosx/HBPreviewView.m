/* HBPreviewView.m

 This file is part of the HandBrake source code.
 Homepage: <http://handbrake.fr/>.
 It may be used under the terms of the GNU General Public License. */

#import "HBPreviewView.h"

// the white border around the preview image
#define BORDER_SIZE 2.0

@interface HBPreviewView ()

@property (nonatomic) CALayer *backLayer;
@property (nonatomic) CALayer *pictureLayer;

@property (nonatomic, readwrite) CGFloat scale;
@property (nonatomic, readwrite) NSRect pictureFrame;

@property (nonatomic, readwrite) CGFloat scaleFactor;

@end

@implementation HBPreviewView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];

    if (self)
    {
        [self setUp];
    }

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];

    if (self)
    {
        [self setUp];
    }

    return self;
}

/**
 *  Setups the sublayers,
 *  called by every initializer.
 */
- (void)setUp
{
    // Make it a layer hosting view
    self.layer = [CALayer new];
    self.wantsLayer = YES;

    _backLayer = [CALayer layer];
    _backLayer.bounds = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height);
    _backLayer.backgroundColor = NSColor.whiteColor.CGColor;
    _backLayer.shadowOpacity = 0.5f;
    _backLayer.shadowOffset = CGSizeZero;
    _backLayer.anchorPoint = CGPointZero;
    _backLayer.opaque = YES;

    _pictureLayer = [CALayer layer];
    _pictureLayer.bounds = CGRectMake(0.0, 0.0, self.frame.size.width - (BORDER_SIZE * 2), self.frame.size.height - (BORDER_SIZE * 2));
    _pictureLayer.anchorPoint = CGPointZero;
    _pictureLayer.opaque = YES;

    // Disable fade on contents change.
    NSMutableDictionary *actions = [NSMutableDictionary dictionary];
    if (_pictureLayer.actions)
    {
        [actions addEntriesFromDictionary:_pictureLayer.actions];
    }

    actions[@"contents"] = [NSNull null];
    _pictureLayer.actions = actions;

    [self.layer addSublayer:_backLayer];
    [self.layer addSublayer:_pictureLayer];

    _pictureLayer.hidden = YES;
    _backLayer.hidden = YES;

    _showBorder = YES;
    _scale = 1;
    _pictureFrame = _pictureLayer.frame;
}

- (void)viewDidChangeBackingProperties
{
    if (self.window)
    {
        self.scaleFactor = self.window.backingScaleFactor;
    }
}

- (void)setImage:(CGImageRef)image
{
    _image = image;
    self.pictureLayer.contents = (__bridge id)(image);

    // Hide the layers if there is no image
    BOOL hidden = _image == nil ? YES : NO;
    self.pictureLayer.hidden = hidden ;
    self.backLayer.hidden = hidden || !self.showBorder;

    [self _updatePreviewLayout];
}

- (void)setFitToView:(BOOL)fitToView
{
    _fitToView = fitToView;
    [self _updatePreviewLayout];
}

- (void)setShowBorder:(BOOL)showBorder
{
    _showBorder = showBorder;
    self.backLayer.hidden = !showBorder;
    [self _updatePreviewLayout];
}

- (void)setShowShadow:(BOOL)showShadow
{
    _backLayer.shadowOpacity = showShadow ? 0.5f : 0;
}

- (void)setFrame:(NSRect)newRect {
    // A change in size has required the view to be invalidated.
    if ([self inLiveResize]) {
        [super setFrame:newRect];
    }
    else {
        [super setFrame:newRect];
    }

    [self _updatePreviewLayout];
}

- (NSSize)scaledSize:(NSSize)source toFit:(NSSize)destination
{
    NSSize result;
    CGFloat sourceAspectRatio = source.width / source.height;
    CGFloat destinationAspectRatio = destination.width / destination.height;

    // Source is larger than screen in one or more dimensions
    if (sourceAspectRatio > destinationAspectRatio)
    {
        // Source aspect wider than screen aspect, snap to max width and vary height
        result.width = destination.width;
        result.height = result.width / sourceAspectRatio;
    }
    else
    {
        // Source aspect narrower than screen aspect, snap to max height vary width
        result.height = destination.height;
        result.width = result.height * sourceAspectRatio;
    }

    return result;
}

/**
 *  Updates the sublayers layout.
 */
- (void)_updatePreviewLayout
{
    // Set the picture size display fields below the Preview Picture
    NSSize imageSize = NSMakeSize(CGImageGetWidth(self.image), CGImageGetHeight(self.image));
    CGFloat backingScaleFactor = 1.0;

    if (imageSize.width > 0 && imageSize.height > 0)
    {
        backingScaleFactor = self.scaleFactor;

        // HiDPI mode usually display everything
        // with double pixel count, but we don't
        // want to double the size of the video
        NSSize imageScaledSize = NSMakeSize(imageSize.width / backingScaleFactor, imageSize.height / backingScaleFactor);
        NSSize frameSize = self.frame.size;

        if (self.showBorder == YES)
        {
            frameSize.width -= BORDER_SIZE * 2;
            frameSize.height -= BORDER_SIZE * 2;
        }

        if (self.fitToView == YES)
        {
            // We are in Fit to View mode so, we have to get the ratio for height and width against the window
            // size so we can scale from there.
            imageScaledSize = [self scaledSize:imageScaledSize toFit:frameSize];
        }
        else if (imageScaledSize.width > frameSize.width || imageScaledSize.height > frameSize.height)
        {
            // If the image is larger then the view, scale the image
            imageScaledSize = [self scaledSize:imageScaledSize toFit:frameSize];
        }

        [NSAnimationContext beginGrouping];
        [NSAnimationContext.currentContext setDuration:0];

        // Resize and position the CALayers
        CGFloat width = imageScaledSize.width + (BORDER_SIZE * 2);
        CGFloat height = imageScaledSize.height + (BORDER_SIZE * 2);

        CGFloat offsetX = (self.frame.size.width - width) / 2;
        CGFloat offsetY = (self.frame.size.height - height) / 2;

        NSRect alignedRect = [self backingAlignedRect:NSMakeRect(offsetX, offsetY, width, height) options:NSAlignAllEdgesNearest];

        self.backLayer.frame = alignedRect;
        self.pictureLayer.frame = NSInsetRect(alignedRect, 2, 2);

        [NSAnimationContext endGrouping];
        
        // Update the properties
        self.scale = self.pictureLayer.frame.size.width / imageSize.width * backingScaleFactor;
        self.pictureFrame = self.pictureLayer.frame;
    }
}

/**
 * Given the size of the preview image to be shown, returns the best possible
 * size for the view.
 */
- (NSSize)optimalViewSizeForImageSize:(NSSize)imageSize minSize:(NSSize)minSize
{
    if (self.scaleFactor != 1.0)
    {
        // HiDPI mode usually display everything
        // with double pixel count, but we don't
        // want to double the size of the video
        imageSize.height /= self.scaleFactor;
        imageSize.width /= self.scaleFactor;
    }

    NSSize screenSize = self.window.screen.visibleFrame.size;
    CGFloat maxWidth = screenSize.width;
    CGFloat maxHeight = screenSize.height;

    NSSize resultSize = imageSize;

    if (resultSize.width > maxWidth || resultSize.height > maxHeight)
    {
        resultSize = [self scaledSize:resultSize toFit:screenSize];
    }

    // If necessary, grow to minimum dimensions to ensure controls overlay is not obstructed
    if (resultSize.width < minSize.width)
    {
        resultSize.width = minSize.width;
    }
    if (resultSize.height < minSize.height)
    {
        resultSize.height = minSize.height;
    }

    // Add the border
    if (self.showBorder)
    {
        resultSize.width += BORDER_SIZE * 2;
        resultSize.height += BORDER_SIZE * 2;
    }

    NSRect alignedRect = [self backingAlignedRect:NSMakeRect(0, 0, resultSize.width, resultSize.height)
                                          options:NSAlignAllEdgesNearest];

    resultSize.width = alignedRect.size.width;
    resultSize.height = alignedRect.size.height;

    return resultSize;
}

#pragma mark - Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (NSString *)accessibilityRole
{
    return NSAccessibilityImageRole;
}

- (NSString *)accessibilityLabel
{
    if (self.image)
    {
        return [NSString stringWithFormat:NSLocalizedString(@"Preview Image, Size: %zu x %zu, Scale: %.0f%%", @"Preview -> accessibility label"), CGImageGetWidth(self.image), CGImageGetHeight(self.image), self.scale * 100];
    }
    return NSLocalizedString(@"No image", @"Preview -> accessibility label");
}

@end
