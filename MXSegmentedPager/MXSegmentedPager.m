// MXSegmentedPager.m
//
// CopyLeading (c) 2015 Maxime Epain
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the Leadings
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyLeading notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYLeading HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <objc/runtime.h>
#import "MXSegmentedPager.h"

typedef NS_ENUM(NSInteger, MXPanGestureDirection) {
    MXPanGestureDirectionNone       = 1 << 0,
    MXPanGestureDirectionLeading    = 1 << 1,
    MXPanGestureDirectionTrailing   = 1 << 2,
    MXPanGestureDirectionUp         = 1 << 3,
    MXPanGestureDirectionDown       = 1 << 4
};

@interface MXScrollView : UIScrollView <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, assign) CGFloat minimumHeigth;
@property (nonatomic, strong) MXSegmentedPager *segmentedPager;
@property (nonatomic, strong) MXProgressBlock progressBlock;
@property (nonatomic, strong) NSMutableArray *observedViews;
@end


@interface MXSegmentedPager () <MXPagerViewDelegate, MXPagerViewDataSource>

// Page count
@property (nonatomic, assign) NSInteger count;

// Subviews
@property (nonatomic, strong) MXScrollView *contentView;
//@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) HMSegmentedControl* segmentedControl;
@property (nonatomic, strong) MXPagerView* pager;

// Constraints
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *controlTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *controlTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *controlLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *controlHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *controlCenterXConstraint;

@property (nonatomic, strong) NSLayoutConstraint *pagerTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *pagerBottomtConstraint;
@property (nonatomic, strong) NSLayoutConstraint *pagerCenterYConstraint;

@property (nonatomic, strong) NSLayoutConstraint *contentBottomConstraint;

@end

@implementation MXSegmentedPager {
    BOOL _moveSegment;
}

@synthesize segmentedControlHeight = _segmentedControlHeight;

- (void)layoutSubviews {
    [super layoutSubviews];
    [self reloadData];
    
    [self.contentView layoutIfNeeded];
    [self.pager layoutIfNeeded];
}

- (void)reloadData {
    
    self.count = 1;
    if ([self.dataSource respondsToSelector:@selector(numberOfPagesInSegmentedPager:)]) {
        self.count = [self.dataSource numberOfPagesInSegmentedPager:self];
    }
    
    //Gets new data
    NSMutableArray* images  = [NSMutableArray array];
    NSMutableArray* titles  = [NSMutableArray array];
    
    for (NSInteger index = 0; index < self.count; index++) {
        
        NSString* title = [NSString stringWithFormat:@"Page %ld", (long)index];
        if ([self.dataSource respondsToSelector:@selector(segmentedPager:titleForSectionAtIndex:)]) {
            title = [self.dataSource segmentedPager:self titleForSectionAtIndex:index];
        }
        [titles addObject:title];
        
        if ([self.dataSource respondsToSelector:@selector(segmentedPager:imageForSectionAtIndex:)]) {
            UIImage* image = [self.dataSource segmentedPager:self imageForSectionAtIndex:index];
            [images addObject:image];
        }
    }
    
    if (images.count > 0) {
        self.segmentedControl.sectionImages = images;
    }
    else {
        self.segmentedControl.sectionTitles = titles;
    }
}

- (void) scrollToPageAtIndex:(NSInteger)index animated:(BOOL)animated {
    [self.segmentedControl setSelectedSegmentIndex:index animated:animated];
    [self.pager showPageAtIndex:index animated:animated];
}

#pragma mark Properties

- (MXScrollView *)contentView {
    if (!_contentView) {
        
        // Create scroll-view
        _contentView = [[MXScrollView alloc] init];
        _contentView.segmentedPager = self;
        _contentView.scrollEnabled = NO;
        [self addSubview:_contentView];
        
        [self updateContentViewConstraints];
    }
    return _contentView;
}

- (HMSegmentedControl *)segmentedControl {
    if (!_segmentedControl) {
        _segmentedControl = [[HMSegmentedControl alloc] init];
        [_segmentedControl addTarget:self
                              action:@selector(pageControlValueChanged:)
                    forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_segmentedControl];
        
        self.segmentedControlEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
        
        [self updateSegmentedControlConstraints];
        
        _moveSegment = YES;
    }
    return _segmentedControl;
}

- (MXPagerView *)pager {
    if (!_pager) {
        _pager = [[MXPagerView alloc] init];
        _pager.delegate = self;
        _pager.dataSource = self;
        [self.contentView addSubview:_pager];
        
        [self updatePagerConstraints];
    }
    return _pager;
}

- (UIView*) selectedPage {
    return self.pager.selectedPage;
}

- (CGFloat)segmentedControlHeight {
    if (_segmentedControlHeight <= 0) {
        _segmentedControlHeight = 44.f;
    }
    return _segmentedControlHeight;
}

- (void)setSegmentedControlHeight:(CGFloat)segmentedControlHeight {
    _segmentedControlHeight = segmentedControlHeight;
    
    self.controlHeightConstraint.constant = segmentedControlHeight;
    
    CGFloat constant = segmentedControlHeight;
    constant        += self.segmentedControlEdgeInsets.top;
    constant        += self.segmentedControlEdgeInsets.bottom;
    constant        /= 2;
    self.pagerCenterYConstraint.constant = constant;
    
    [self.contentView layoutIfNeeded];
    [self.pager layoutIfNeeded];
}

- (void)setSegmentedControlEdgeInsets:(UIEdgeInsets)segmentedControlEdgeInsets {
    _segmentedControlEdgeInsets = segmentedControlEdgeInsets;
    
    self.controlTopConstraint.constant      = segmentedControlEdgeInsets.top;
    self.controlLeadingConstraint.constant  = segmentedControlEdgeInsets.left;
    self.controlTrailingConstraint.constant = -segmentedControlEdgeInsets.right;
    self.pagerTopConstraint.constant        = segmentedControlEdgeInsets.bottom;
    
    CGFloat constant = segmentedControlEdgeInsets.left - segmentedControlEdgeInsets.right;
    self.controlCenterXConstraint.constant  = constant;
    
    constant = self.segmentedControlHeight;
    constant += segmentedControlEdgeInsets.top;
    constant += segmentedControlEdgeInsets.bottom;
    constant /= 2;
    self.pagerCenterYConstraint.constant = constant;
    
    [self.contentView layoutIfNeeded];
    [self.pager layoutIfNeeded];
}

#pragma mark HMSegmentedControl target

- (void)pageControlValueChanged:(HMSegmentedControl*)segmentedControl {
    _moveSegment = NO;
    [self.pager showPageAtIndex:segmentedControl.selectedSegmentIndex animated:YES];
}

#pragma mark <MXPagerViewDelegate>

- (void)pagerView:(MXPagerView *)pagerView willMoveToPageAtIndex:(NSInteger)index {
    if (_moveSegment) {
        [self.segmentedControl setSelectedSegmentIndex:index animated:YES];
    }
}

- (void)pagerView:(MXPagerView *)pagerView didMoveToPageAtIndex:(NSInteger)index {
    [self.segmentedControl setSelectedSegmentIndex:index animated:NO];
    [self changedToIndex:index];
    _moveSegment = YES;
}

#pragma mark <MXPagerViewDataSource>

- (NSInteger)numberOfPagesInPagerView:(MXPagerView *)pagerView {
    return self.count;
}

- (UIView*) pagerView:(MXPagerView *)pagerView viewForPageAtIndex:(NSInteger)index {
    return [self.dataSource segmentedPager:self viewForPageAtIndex:index];
}

#pragma mark Private methods

- (void) changedToIndex:(NSInteger)index {
    if ([self.delegate respondsToSelector:@selector(segmentedPager:didSelectViewWithIndex:)]) {
        [self.delegate segmentedPager:self didSelectViewWithIndex:index];
    }
    
    NSString* title = self.segmentedControl.sectionTitles[index];
    UIView* view = self.pager.selectedPage;
                    
    if ([self.delegate respondsToSelector:@selector(segmentedPager:didSelectViewWithTitle:)]) {
        [self.delegate segmentedPager:self didSelectViewWithTitle:title];
    }
    
    if ([self.delegate respondsToSelector:@selector(segmentedPager:didSelectView:)]) {
        [self.delegate segmentedPager:self didSelectView:view];
    }
}

#pragma mark Content view constraints

- (void) updateContentViewConstraints {
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[v]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:@{@"v" : self.contentView}]];
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self.contentView
                                                     attribute:NSLayoutAttributeTop
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeTop
                                                    multiplier:1
                                                      constant:0]];
    
    [self addConstraint:self.contentBottomConstraint];
}

- (NSLayoutConstraint *)contentBottomConstraint {
    if (!_contentBottomConstraint) {
        _contentBottomConstraint = [NSLayoutConstraint constraintWithItem:self.contentView
                                                                attribute:NSLayoutAttributeBottom
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:self
                                                                attribute:NSLayoutAttributeBottom
                                                               multiplier:1
                                                                 constant:0];
    }
    return _contentBottomConstraint;
}

#pragma mark Segmented-control constraints

- (void) updateSegmentedControlConstraints {
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.contentView addConstraint:self.controlTopConstraint];
    [self.contentView addConstraint:self.controlTrailingConstraint];
    [self.contentView addConstraint:self.controlLeadingConstraint];
    [self.contentView addConstraint:self.controlHeightConstraint];
    [self.contentView addConstraint:self.controlCenterXConstraint];
}

- (NSLayoutConstraint *)controlTopConstraint {
    if (!_controlTopConstraint) {
        _controlTopConstraint = [NSLayoutConstraint constraintWithItem:self.segmentedControl
                                                             attribute:NSLayoutAttributeTop
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.contentView
                                                             attribute:NSLayoutAttributeTop
                                                            multiplier:1
                                                              constant:self.segmentedControlEdgeInsets.top];
    }
    return _controlTopConstraint;
}

- (NSLayoutConstraint *)controlTrailingConstraint {
    if (!_controlTrailingConstraint) {
        _controlTrailingConstraint = [NSLayoutConstraint constraintWithItem:self.segmentedControl
                                                                  attribute:NSLayoutAttributeTrailing
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.contentView
                                                                  attribute:NSLayoutAttributeTrailing
                                                                 multiplier:1
                                                                   constant:-self.segmentedControlEdgeInsets.right];
    }
    return _controlTrailingConstraint;
}

- (NSLayoutConstraint *)controlLeadingConstraint {
    if (!_controlLeadingConstraint) {
        _controlLeadingConstraint = [NSLayoutConstraint constraintWithItem:self.segmentedControl
                                                                 attribute:NSLayoutAttributeLeading
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.contentView
                                                                 attribute:NSLayoutAttributeLeading
                                                                multiplier:1
                                                                  constant:self.segmentedControlEdgeInsets.left];
    }
    return _controlLeadingConstraint;
}

- (NSLayoutConstraint *)controlHeightConstraint {
    if (!_controlHeightConstraint) {
        _controlHeightConstraint = [NSLayoutConstraint constraintWithItem:self.segmentedControl
                                                                attribute:NSLayoutAttributeHeight
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:nil
                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                               multiplier:1
                                                                 constant:0];
        
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self addConstraint:self.heightConstraint];
    }
    return _controlHeightConstraint;
}

- (NSLayoutConstraint *)controlCenterXConstraint {
    if (!_controlCenterXConstraint) {
        
        CGFloat constant = self.segmentedControlEdgeInsets.left - self.segmentedControlEdgeInsets.right;
        _controlCenterXConstraint = [NSLayoutConstraint constraintWithItem:self.segmentedControl
                                                                 attribute:NSLayoutAttributeCenterX
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.contentView
                                                                 attribute:NSLayoutAttributeCenterX
                                                                multiplier:1
                                                                  constant:constant];
    }
    return _controlCenterXConstraint;
}

- (NSLayoutConstraint *)heightConstraint{
    if (!_heightConstraint) {
        _heightConstraint = [NSLayoutConstraint constraintWithItem:self
                                                         attribute:NSLayoutAttributeHeight
                                                         relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                            toItem:self.segmentedControl
                                                         attribute:NSLayoutAttributeHeight
                                                        multiplier:1
                                                          constant:0];
    }
    return _heightConstraint;
}

#pragma mark Pager constraints

- (void)updatePagerConstraints {
    self.pager.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[v]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:@{@"v" : self.pager}]];
    [self.contentView addConstraint:self.pagerTopConstraint];
    [self.contentView addConstraint:self.pagerCenterYConstraint];
    [self.contentView addConstraint:self.pagerBottomtConstraint];
}

- (NSLayoutConstraint *)pagerTopConstraint {
    if (!_pagerTopConstraint) {
        _pagerTopConstraint = [NSLayoutConstraint constraintWithItem:self.pager
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:self.segmentedControl
                                                           attribute:NSLayoutAttributeBottom
                                                          multiplier:1
                                                            constant:self.segmentedControlEdgeInsets.bottom];
    }
    return _pagerTopConstraint;
}

- (NSLayoutConstraint *)pagerBottomtConstraint {
    if (!_pagerBottomtConstraint) {
        _pagerBottomtConstraint = [NSLayoutConstraint constraintWithItem:self.pager
                                                               attribute:NSLayoutAttributeBottom
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.contentView
                                                               attribute:NSLayoutAttributeBottom
                                                              multiplier:1
                                                                constant:0];
    }
    return _pagerBottomtConstraint;
}

- (NSLayoutConstraint *)pagerCenterYConstraint {
    if (!_pagerCenterYConstraint) {
        CGFloat constant = self.segmentedControlHeight;
        constant += self.segmentedControlEdgeInsets.top;
        constant += self.segmentedControlEdgeInsets.bottom;
        constant /= 2;
        
        _pagerCenterYConstraint = [NSLayoutConstraint constraintWithItem:self.pager
                                                               attribute:NSLayoutAttributeCenterY
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.contentView
                                                               attribute:NSLayoutAttributeCenterY
                                                              multiplier:1
                                                                constant:constant];
    }
    return _pagerCenterYConstraint;
}

@end

@implementation MXSegmentedPager (ParallaxHeader)

#pragma mark VGParallaxHeader

- (void)setParallaxHeaderView:(UIView *)view mode:(VGParallaxHeaderMode)mode height:(CGFloat)height {
    [self.contentView setParallaxHeaderView:view mode:mode height:height];
    
    self.contentView.scrollEnabled = view;
}

- (VGParallaxHeader *)parallaxHeader {
    return self.contentView.parallaxHeader;
}

#pragma mark Properties

- (CGFloat)minimumHeaderHeight {
    return self.contentView.minimumHeigth;
}

- (void)setMinimumHeaderHeight:(CGFloat)minimumHeaderHeight {
    self.contentView.minimumHeigth = minimumHeaderHeight;
}

- (MXProgressBlock)progressBlock {
    return self.contentView.progressBlock;
}

- (void)setProgressBlock:(MXProgressBlock)progressBlock {
    self.contentView.progressBlock = progressBlock;
}

@end

@implementation MXScrollView {
    BOOL _isObserving;
    BOOL _lock;
}

static void * const kMXScrollViewKVOContext = (void*)&kMXScrollViewKVOContext;
static NSString* const kContentOffsetKeyPath = @"contentOffset";

- (instancetype)init {
    self = [super init];
    if (self) {
        self.delegate = self;
        self.showsVerticalScrollIndicator = NO;
        self.directionalLockEnabled = YES;
        self.bounces = YES;
        self.minimumHeigth = 0;
    }
    return self;
}

#pragma mark Properties

- (NSMutableArray *)observedViews {
    if (!_observedViews) {
        _observedViews = [NSMutableArray array];
    }
    return _observedViews;
}

- (void)setScrollEnabled:(BOOL)scrollEnabled {
    [super setScrollEnabled:scrollEnabled];
    
    if (scrollEnabled) {
        [self addObserver:self forKeyPath:kContentOffsetKeyPath
                  options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
                  context:kMXScrollViewKVOContext];
    }
    else {
        @try {
            [self removeObserver:self forKeyPath:kContentOffsetKeyPath];
        }
        @catch (NSException *exception) {}
    }
}

#pragma mark <UIScrollViewDelegate>

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if ((self.contentOffset.y >= -self.minimumHeigth)) {
        self.contentOffset = CGPointMake(self.contentOffset.x, -self.minimumHeigth);
    }
    
    [scrollView shouldPositionParallaxHeader];
    
    if (self.progressBlock) {
        self.progressBlock(scrollView.parallaxHeader.progress);
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    _lock = NO;
    [self removeObservedViews];
}

#pragma mark <UIGestureRecognizerDelegate>

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        MXPanGestureDirection direction = [self getDirectionOfPanGestureRecognizer:(UIPanGestureRecognizer*)gestureRecognizer];
        
        if (direction == MXPanGestureDirectionTrailing || direction == MXPanGestureDirectionLeading) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    
    UIView<MXPageProtocol> *page = (id) self.segmentedPager.pager.selectedPage;
    BOOL shouldScroll = self.scrollEnabled;
    
    if ([page respondsToSelector:@selector(segmentedPager:shouldScrollWithView:)]) {
        shouldScroll = [page segmentedPager:self.segmentedPager shouldScrollWithView:otherGestureRecognizer.view];
    }
    
    if (shouldScroll) {
        [self addObservedView:otherGestureRecognizer.view];
    }
    return shouldScroll;
}

- (MXPanGestureDirection) getDirectionOfPanGestureRecognizer:(UIPanGestureRecognizer*) panGestureRecognizer {
    
    CGPoint velocity = [panGestureRecognizer velocityInView:self];
    CGFloat absX = fabs(velocity.x);
    CGFloat absY = fabs(velocity.y);
    
    if (absX > absY) {
        return (velocity.x > 0)? MXPanGestureDirectionLeading : MXPanGestureDirectionTrailing;
    }
    else if (absX < absY) {
        return (velocity.y > 0)? MXPanGestureDirectionDown : MXPanGestureDirectionUp;
    }
    return MXPanGestureDirectionNone;
}

#pragma mark KVO

- (void) addObserverToView:(UIView *)view {
    _isObserving = NO;
    if ([view isKindOfClass:[UIScrollView class]]) {
        [view addObserver:self
               forKeyPath:kContentOffsetKeyPath
                  options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew
                  context:kMXScrollViewKVOContext];
    }
    _isObserving = YES;
}

- (void) removeObserverFromView:(UIView *)view {
    @try {
        if ([view isKindOfClass:[UIScrollView class]]) {
            [view removeObserver:self
                      forKeyPath:kContentOffsetKeyPath
                         context:kMXScrollViewKVOContext];
        }
    }
    @catch (NSException *exception) {}
}

//This is where the magic happens...
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if (context == kMXScrollViewKVOContext && [keyPath isEqualToString:kContentOffsetKeyPath]) {
        
        CGPoint new = [[change objectForKey:NSKeyValueChangeNewKey] CGPointValue];
        CGPoint old = [[change objectForKey:NSKeyValueChangeOldKey] CGPointValue];
        
        if (old.y == new.y) return;
        
        if (_isObserving && object == self) {
            //Adjust self scroll offset
            if ((old.y - new.y) > 0 && _lock) {
                [self contentView:self setContentOffset:old];
            }
        }
        else if (_isObserving && [object isKindOfClass:[UIScrollView class]]) {
            
            //Adjust the observed contentView's content offset
            MXScrollView *scrollView = object;
            _lock = !(scrollView.contentOffset.y <= -scrollView.contentInset.top);
            
            //Manage scroll up
            if (self.contentOffset.y < -self.minimumHeigth && _lock && (old.y - new.y) < 0) {
                [self contentView:scrollView setContentOffset:old];
            }
            //Disable bouncing when scroll down
            if (!_lock) {
                [self contentView:scrollView setContentOffset:CGPointMake(scrollView.contentOffset.x, -scrollView.contentInset.top)];
            }
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Scrolling views handlers

- (void) addObservedView:(UIView *)view {
    if (![self.observedViews containsObject:view]) {
        [self.observedViews addObject:view];
        [self addObserverToView:view];
    }
}

- (void) removeObservedViews {
    for (UIView *view in self.observedViews) {
        [self removeObserverFromView:view];
    }
    [self.observedViews removeAllObjects];
}

- (void) contentView:(UIScrollView*)contentView setContentOffset:(CGPoint)offset {
    _isObserving = NO;
    contentView.contentOffset = offset;
    _isObserving = YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

