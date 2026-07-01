using System.Windows;
using RongYokDownloader.ViewModels;

namespace RongYokDownloader.Views;

public partial class WhatsNewWindow : Window
{
    public WhatsNewWindow()
    {
        InitializeComponent();
        DataContextChanged += (_, e) =>
        {
            if (e.OldValue is WhatsNewViewModel oldVm) oldVm.CloseRequested -= Close;
            if (e.NewValue is WhatsNewViewModel newVm) newVm.CloseRequested += Close;
        };
    }
}
