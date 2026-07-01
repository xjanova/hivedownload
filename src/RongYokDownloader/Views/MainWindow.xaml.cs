using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using RongYokDownloader.ViewModels;

namespace RongYokDownloader.Views;

public partial class MainWindow : Window
{
    private MainViewModel? _vm;

    public MainWindow()
    {
        InitializeComponent();
        SourceInitialized += (_, _) => TryEnableDarkTitleBar();
        DataContextChanged += OnDataContextChanged;
    }

    private void OnDataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
    {
        if (_vm is not null) _vm.ShowWhatsNewRequested -= ShowWhatsNew;
        _vm = DataContext as MainViewModel;
        if (_vm is not null) _vm.ShowWhatsNewRequested += ShowWhatsNew;
    }

    private void ShowWhatsNew(WhatsNewViewModel whatsNewVm)
    {
        var win = new WhatsNewWindow { DataContext = whatsNewVm, Owner = this };
        win.ShowDialog();
    }

    // Paint the native title bar dark to match the app (Windows 10 2004+ / Windows 11).
    private const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

    private void TryEnableDarkTitleBar()
    {
        try
        {
            var hwnd = new WindowInteropHelper(this).Handle;
            int on = 1;
            DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, ref on, sizeof(int));
        }
        catch { /* older Windows — harmless */ }
    }
}
