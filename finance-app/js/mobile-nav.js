/**
 * Mobile Navigation Controller
 * Handles bottom navigation, FAB button, and mobile-specific interactions
 */

class MobileNavController {
    constructor() {
        this.isMobile = window.innerWidth <= 768;
        this.currentPage = 'dashboard';
        this.init();
    }

    init() {
        if (!this.isMobile) return;

        this.showMobileUI();
        this.bindEvents();
        this.initializeFAB();

        // Listen for resize events
        window.addEventListener('resize', () => {
            this.isMobile = window.innerWidth <= 768;
            if (this.isMobile) {
                this.showMobileUI();
            } else {
                this.hideMobileUI();
            }
        });
    }

    showMobileUI() {
        const bottomNav = document.getElementById('mobileBottomNav');
        const fab = document.getElementById('mobileFAB');

        if (bottomNav) bottomNav.style.display = 'flex';
        if (fab) fab.style.display = 'flex';
    }

    hideMobileUI() {
        const bottomNav = document.getElementById('mobileBottomNav');
        const fab = document.getElementById('mobileFAB');

        if (bottomNav) bottomNav.style.display = 'none';
        if (fab) fab.style.display = 'none';
    }

    bindEvents() {
        // Bottom navigation items
        const navItems = document.querySelectorAll('.bottom-nav-item');
        navItems.forEach(item => {
            item.addEventListener('click', (e) => {
                const page = item.getAttribute('data-page');
                this.navigateToPage(page);
            });
        });

        // FAB button - triggers appropriate action based on current page
        const fab = document.getElementById('mobileFAB');
        if (fab) {
            fab.addEventListener('click', () => {
                this.handleFABClick();
            });
        }

        // Update nav on page change
        document.addEventListener('pageChange', (e) => {
            this.updateActiveNav(e.detail.page);
        });
    }

    navigateToPage(page) {
        // Use existing navigation system
        const navLink = document.querySelector(`[data-page="${page}"]`);
        if (navLink && navLink.classList.contains('nav-link')) {
            navLink.click();
        }

        this.updateActiveNav(page);
        this.currentPage = page;

        // Add smooth scroll to top
        const pageContainer = document.querySelector('.page-container');
        if (pageContainer) {
            pageContainer.scrollTo({ top: 0, behavior: 'smooth' });
        }
    }

    updateActiveNav(page) {
        const navItems = document.querySelectorAll('.bottom-nav-item');
        navItems.forEach(item => {
            if (item.getAttribute('data-page') === page) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });
    }

    initializeFAB() {
        // Show/hide FAB based on scroll position
        const pageContainer = document.querySelector('.page-container');
        if (!pageContainer) return;

        let lastScrollTop = 0;
        pageContainer.addEventListener('scroll', () => {
            const scrollTop = pageContainer.scrollTop;
            const fab = document.getElementById('mobileFAB');

            if (!fab) return;

            // Hide FAB when scrolling down, show when scrolling up
            if (scrollTop > lastScrollTop && scrollTop > 100) {
                fab.classList.add('hidden');
            } else {
                fab.classList.remove('hidden');
            }

            lastScrollTop = scrollTop;
        });
    }

    handleFABClick() {
        // Determine which button to click based on current page
        const fabActions = {
            'dashboard': '#addEntryBtn',
            'entries': '#addEntryBtn',
            'clients': '#addClientBtn',
            'invoices': '#createInvoiceBtn',
            'employees': '#addEmployeeBtn',
            'investments': '#addInvestmentBtn',
            'petty-cash': '#addPettyCashBtn'
        };

        const buttonSelector = fabActions[this.currentPage];
        if (buttonSelector) {
            const button = document.querySelector(buttonSelector);
            if (button) {
                button.click();

                // Add haptic feedback for mobile devices
                if ('vibrate' in navigator) {
                    navigator.vibrate(10);
                }
            }
        }
    }

    // Public method to update current page
    setCurrentPage(page) {
        this.currentPage = page;
        this.updateActiveNav(page);
    }
}

// Initialize mobile navigation when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    // Small delay to ensure other scripts are loaded
    setTimeout(() => {
        window.mobileNav = new MobileNavController();
    }, 100);
});

// Update mobile nav when page changes (hook into existing navigation)
const originalShowPage = window.showPage || function () { };
window.showPage = function (pageName) {
    originalShowPage.apply(this, arguments);

    if (window.mobileNav) {
        window.mobileNav.setCurrentPage(pageName);
    }
};

// Add pull-to-refresh functionality (optional enhancement)
class PullToRefresh {
    constructor() {
        this.touchStartY = 0;
        this.touchEndY = 0;
        this.isPulling = false;
        this.threshold = 80;

        if (window.innerWidth <= 768) {
            this.init();
        }
    }

    init() {
        const pageContainer = document.querySelector('.page-container');
        if (!pageContainer) return;

        pageContainer.addEventListener('touchstart', (e) => {
            this.touchStartY = e.touches[0].clientY;
        }, { passive: true });

        pageContainer.addEventListener('touchmove', (e) => {
            this.touchEndY = e.touches[0].clientY;
            const scrollTop = pageContainer.scrollTop;

            // Only trigger if at the top of the page
            if (scrollTop === 0) {
                const pullDistance = this.touchEndY - this.touchStartY;

                if (pullDistance > 0 && pullDistance < this.threshold) {
                    this.isPulling = true;
                }
            }
        }, { passive: true });

        pageContainer.addEventListener('touchend', () => {
            if (this.isPulling) {
                const pullDistance = this.touchEndY - this.touchStartY;

                if (pullDistance >= this.threshold) {
                    this.refresh();
                }

                this.isPulling = false;
            }
        });
    }

    refresh() {
        // Trigger a page refresh - reload current data
        if (window.app && typeof window.app.loadDashboard === 'function') {
            window.app.loadDashboard();
        }

        // Show a subtle feedback
        if (window.showToast) {
            showToast('Refreshing...', 'info');
        }

        // Haptic feedback
        if ('vibrate' in navigator) {
            navigator.vibrate(20);
        }
    }
}

// Initialize pull-to-refresh
document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        new PullToRefresh();
    }, 200);
});

// Prevent double-tap zoom on buttons (iOS Safari fix)
document.addEventListener('DOMContentLoaded', () => {
    if (window.innerWidth <= 768) {
        let lastTouchEnd = 0;
        document.addEventListener('touchend', (e) => {
            const now = Date.now();
            if (now - lastTouchEnd <= 300) {
                e.preventDefault();
            }
            lastTouchEnd = now;
        }, false);
    }
});

// Add safe area support for devices with notches
if (window.innerWidth <= 768) {
    const metaViewport = document.querySelector('meta[name="viewport"]');
    if (metaViewport) {
        metaViewport.setAttribute('content',
            'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover'
        );
    }
}
