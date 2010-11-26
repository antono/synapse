/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *             Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;

namespace Synapse
{
  public class UILauncher
  {
    private static bool is_startup = false;
    const OptionEntry[] options =
    {
      {
        "startup", 's', 0, OptionArg.NONE,
        out is_startup, "Startup mode (don't show the UI immediately)", ""
      },
      {
        null
      }
    };
    
    private UIInterface ui;
    private SettingsWindow settings;
    private DataSink data_sink;
    private GtkHotkey.Info? hotkey;
    private Inspector inspector;
    private Configuration config;
    
    public UILauncher ()
    {
      ui = null;
      config = Configuration.get_default ();
      data_sink = new DataSink ();
      settings = new SettingsWindow (data_sink);
      settings.keybinding_changed.connect (this.change_keyboard_shortcut);
      
      bind_keyboard_shortcut ();
      
      init_ui (settings.get_current_theme ());
      if (!is_startup) ui.show ();
      
      settings.theme_selected.connect (init_ui);
#if ENABLE_INSPECTOR
      inspector = new Inspector ();
#endif
    }
    private void init_ui (Type t)
    {
      ui = GLib.Object.new (t, "data-sink", data_sink) as UIInterface;
      ui.show_settings_clicked.connect (()=>{
        settings.show ();
      });
    }
    private void bind_keyboard_shortcut ()
    {
      var registry = GtkHotkey.Registry.get_default ();
      try
      {
        if (registry.has_hotkey ("synapse", "activate"))
        {
          hotkey = registry.get_hotkey ("synapse", "activate");
        }
        else
        {
          hotkey = new GtkHotkey.Info ("synapse", "activate",
                                       "<Control>space", null);
          registry.store_hotkey (hotkey);
        }
        debug ("Binding activation to %s", hotkey.signature);
        settings.set_keybinding (hotkey.signature, false);
        hotkey.bind ();
        hotkey.activated.connect ((event_time) =>
        {
          if (this.ui == null) return;
          this.ui.show ();
          this.ui.present_with_time (event_time);
        });
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }/* */
    }
    
    private void change_keyboard_shortcut (string key)
    {
      var registry = GtkHotkey.Registry.get_default ();
      try
      {
        if (hotkey.is_bound ()) hotkey.unbind ();
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      
      try
      {
        if (registry.has_hotkey ("synapse", "activate"))
        {
          registry.delete_hotkey ("synapse", "activate");
        }
        
        if (key != "")
        {
          hotkey = new GtkHotkey.Info ("synapse", "activate",
                                       key, null);
          registry.store_hotkey (hotkey);
          hotkey.bind ();
          hotkey.activated.connect ((event_time) =>
          {
            if (this.ui == null) return;
            this.ui.show ();
            this.ui.present_with_time (event_time);
          });
        }
      }
      catch (Error err)
      {
        Gtk.MessageDialog dialog = new Gtk.MessageDialog (this.settings, 0,
          Gtk.MessageType.WARNING, Gtk.ButtonsType.OK,
          "%s", err.message
        );
        dialog.run ();
        dialog.destroy ();
      }
    }

    public void run ()
    {
      Environment.unset_variable ("DESKTOP_AUTOSTART_ID");
      Gtk.main ();
    }

    public static int main (string[] argv)
    {
      var context = new OptionContext (" - Awn Applet Activation Options");
      context.add_main_entries (options, null);
      context.add_group (Gtk.get_option_group (false));
      try
      {
        context.parse (ref argv);

        Gtk.init (ref argv);
        var launcher = new UILauncher ();
        launcher.run ();
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      return 0;
    }
  }
}