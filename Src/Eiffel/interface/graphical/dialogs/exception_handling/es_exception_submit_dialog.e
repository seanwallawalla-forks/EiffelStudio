note
	description: "[
		Dialog that submit exception as bug report to http://support.eiffel.com
	]"
	date: "$Date$"
	revision: "$Revision$"

class
	ES_EXCEPTION_SUBMIT_DIALOG

inherit

	ES_DIALOG
		rename
			make as make_dialog
		redefine
			on_after_initialized
		end

	SYSTEM_CONSTANTS
		export
			{NONE} all
		end

create
	make

feature {NONE} -- Initialization

	make (a_support_url: like support_url; a_comm: like support_login; a_last_description: like last_description)
			-- Set `last_description' with `a_description', `a_last_description' can be void
		require
			a_comm_attached: a_comm /= Void
			a_comm_is_support_accessible: a_comm.is_support_accessible
		do
			support_url := a_support_url
			support_login := a_comm
			last_description := a_last_description

			make_dialog
		ensure
			support_login_set: support_login = a_comm
			set: last_description = a_last_description
		end

	build_dialog_interface (a_container: EV_VERTICAL_BOX)
			-- Builds the dialog's user interface.
			--
			-- `a_container': The dialog's container where the user interface elements should be extended
		local
			l_vbox: EV_VERTICAL_BOX
			l_width: INTEGER
			l_user_label: EV_LABEL
			l_pass_label: EV_LABEL
			l_text: EV_LABEL
			l_link: EV_LINK_LABEL
			l_hbox: EV_HORIZONTAL_BOX
			l_shrinkable: EV_FIXED
			l_string: STRING_32
		do
			a_container.set_padding ({ES_UI_CONSTANTS}.vertical_padding)

			create login_frame.make_with_text (locale_formatter.translation (t_account_access))
			create l_vbox
			l_vbox.set_padding ({ES_UI_CONSTANTS}.vertical_padding)
			l_vbox.set_border_width ({ES_UI_CONSTANTS}.frame_border)
			login_frame.extend (l_vbox)


				-- Username and password
			create l_user_label.make_with_text (locale_formatter.translation (lb_username))
			l_user_label.align_text_right
			create l_pass_label.make_with_text (locale_formatter.translation (lb_password))
			l_pass_label.align_text_right
			l_width := l_user_label.width.max (l_pass_label.width)
			l_user_label.set_minimum_width (l_width)
			l_pass_label.set_minimum_width (l_width)

				-- Username
			create l_hbox
			l_hbox.set_padding ({ES_UI_CONSTANTS}.horizontal_padding)
			l_hbox.extend (l_user_label)
			l_hbox.disable_item_expand (l_user_label)
			create username_text
			username_text.set_minimum_width (190)
			register_action (username_text.change_actions, agent enable_login)
			suppress_confirmation_key_close (username_text)
			l_hbox.extend (username_text)

			l_vbox.extend (l_hbox)
			l_vbox.disable_item_expand (l_hbox)

				-- Password
			create l_hbox
			l_hbox.set_padding ({ES_UI_CONSTANTS}.horizontal_padding)
			l_hbox.extend (l_pass_label)
			l_hbox.disable_item_expand (l_pass_label)
			create password_text
			register_action (password_text.change_actions, agent enable_login)
			register_action (password_text.key_press_actions, agent on_password_key_pressed)
			suppress_confirmation_key_close (password_text)
			password_text.set_minimum_width (190)
			l_hbox.extend (password_text)

			l_vbox.extend (l_hbox)
			l_vbox.disable_item_expand (l_hbox)

				-- Remember me check
			create l_hbox
			l_hbox.set_padding ({ES_UI_CONSTANTS}.horizontal_padding)
			l_hbox.extend (create {EV_CELL})
			create remember_me_check.make_with_text (locale_formatter.translation (lb_remember_me))
			register_action (remember_me_check.select_actions, agent on_remember_me_toggled)
			l_hbox.extend (remember_me_check)
			l_hbox.disable_item_expand (remember_me_check)

			if session_manager.service = Void then
					-- Remembering the user's details uses the session manager service, so if it's unavailble then
					-- we there is no point showing the check mark
				remember_me_check.hide
			end

			create login_button.make_with_text (locale_formatter.translation (b_login))
			login_button.set_minimum_width ({ES_UI_CONSTANTS}.dialog_button_width)
			register_action (login_button.select_actions, agent on_login)
			suppress_confirmation_key_close (login_button)
			l_hbox.extend (login_button)
			l_hbox.disable_item_expand (login_button)

			l_vbox.extend (l_hbox)
			l_vbox.disable_item_expand (l_hbox)

				-- Register
			create l_hbox
			create l_text.make_with_text (locale_formatter.translation (lb_register_account))
			l_text.align_text_left
			create l_link.make_with_text (locale_formatter.translation (b_here))
			l_link.select_actions.extend (agent
				local
					l_uri_provider: RAW_URI_HELP_PROVIDER
					l_register_url: STRING_8
					l_error_info: STRING_8
					l_error: ES_ERROR_PROMPT
				do
					create l_uri_provider.make (
						agent (preferences.misc_data.internet_browser_preference).value)
					l_register_url := support_login.register_url
					if support_login.is_bad_request then
						l_error_info := "Unable to register due to network problem. Please try again later."
						create l_error.make_standard (l_error_info)
						l_error.show (dialog)
					else
						l_uri_provider.show_help (support_login.register_url, Void)
					end

				end)

			l_link.align_text_left
			l_hbox.extend (l_text)
			l_hbox.disable_item_expand (l_text)
			l_hbox.extend (l_link)
			l_hbox.disable_item_expand (l_link)

			l_vbox.extend (l_hbox)
			l_vbox.disable_item_expand (l_hbox)

			create l_shrinkable
			l_shrinkable.extend (login_frame)
			shrink_widget := l_shrinkable

			l_shrinkable.resize_actions.extend (agent (a_x: INTEGER_32; a_y: INTEGER_32; a_width: INTEGER_32; a_height: INTEGER_32)
				do
					if a_width > 0 and a_height > 0 then
						shrink_widget.set_item_size (login_frame, a_width, a_height)
					end
				end)

			l_shrinkable.dpi_changed_actions.extend (agent (a_dpi, a_x: INTEGER_32; a_y: INTEGER_32; a_width: INTEGER_32; a_height: INTEGER_32)
				do
					if a_width > 0 and a_height > 0 then
						shrink_widget.set_item_size (login_frame, a_width, a_height)
					end
				end)

			a_container.extend (l_shrinkable)
			a_container.disable_item_expand (l_shrinkable)

				-- Logged in text
			create logged_in_label
			logged_in_label.align_text_left
			logged_in_label.hide

			create log_out_link.make_with_text (locale_formatter.translation (b_log_out))
			log_out_link.select_actions.extend (agent on_logout)
			log_out_link.align_text_left
			log_out_link.hide

			create l_hbox
			l_hbox.extend (logged_in_label)
			l_hbox.disable_item_expand (logged_in_label)
			l_hbox.extend (log_out_link)
			l_hbox.disable_item_expand (log_out_link)

			a_container.extend (l_hbox)
			a_container.disable_item_expand (l_hbox)

				--
				-- More bug information
				--
			create report_frame.make_with_text (locale_formatter.translation (t_bug_information))
			create l_vbox
			l_vbox.set_padding ({ES_UI_CONSTANTS}.vertical_padding)
			l_vbox.set_border_width ({ES_UI_CONSTANTS}.frame_border)
			report_frame.extend (l_vbox)

			a_container.extend (report_frame)

				-- Synopsis
			create synopsis_text
			synopsis_text.set_text (synopsis)
			register_action (synopsis_text.focus_in_actions, agent on_text_component_focused (synopsis_text))
			register_action (synopsis_text.focus_out_actions, agent on_text_component_focused_out (synopsis_text, locale_formatter.translation (lb_enter_synopsis)))
			suppress_confirmation_key_close (synopsis_text)
			l_vbox.extend (synopsis_text)
			l_vbox.disable_item_expand (synopsis_text)

				-- Description
			create description_text
			description_text.set_minimum_size (400, 100)
			register_action (description_text.focus_in_actions, agent on_text_component_focused (description_text))
			register_action (description_text.focus_out_actions, agent on_text_component_focused_out (description_text, default_description))
			suppress_confirmation_key_close (description_text)
			l_vbox.extend (description_text)

				-- Public bug
			create make_public_check.make_with_text (locale_formatter.translation (lb_make_public))
			l_vbox.extend (make_public_check)
			l_vbox.disable_item_expand (make_public_check)

				-- Severity
			create l_hbox
			l_hbox.set_padding ({ES_UI_CONSTANTS}.horizontal_padding)
			create severity_label.make_with_text (locale_formatter.translation (lb_severity))
			l_hbox.extend (severity_label)
			l_hbox.disable_item_expand (severity_label)
			create severity_critical_radio.make_with_text (locale_formatter.translation (i_critical))
			l_hbox.extend (severity_critical_radio)
			l_hbox.disable_item_expand (severity_critical_radio)
			create severity_serious_radio.make_with_text (locale_formatter.translation (i_serious))
			l_hbox.extend (severity_serious_radio)
			l_hbox.disable_item_expand (severity_serious_radio)
			create severity_non_critical_radio.make_with_text (locale_formatter.translation (i_non_critical))
			l_hbox.extend (severity_non_critical_radio)
			l_hbox.disable_item_expand (severity_non_critical_radio)
			l_vbox.extend (l_hbox)
			l_vbox.disable_item_expand (l_hbox)
			severity_serious_radio.enable_select

				-- Add items to login context
			--login_context_item.force_last (l_frame)

				-- Enable content items based on login state.
			on_text_component_focused_out (synopsis_text, locale_formatter.translation (lb_enter_synopsis))
			on_text_component_focused_out (description_text, default_description)
			if description_text.text_length > 0 then
				l_string := description_text.text
				if l_string.item (1).is_character_8 and then l_string.item (1).to_character_8.is_space then
						-- Rese the caret position, because the start of the text is blank.
					description_text.set_caret_position (1)
				end
			end
			enable_login
			enable_login_content_widget (False)

			set_button_text ({ES_DIALOG_BUTTONS}.ok_button, "Submit")
			set_button_action_before_close ({ES_DIALOG_BUTTONS}.ok_button, agent on_submit)

			description_text.focus_in_actions.extend (agent on_focus_in)
			description_text.focus_out_actions.extend (agent on_focus_out)
		end

	on_after_initialized
			-- Use to perform additional creation initializations, after the UI has been created.	
		do
			Precursor {ES_DIALOG}
			if is_user_remembered then
				username_text.set_text (remembered_username)
				password_text.set_text (remembered_password)
				remember_me_check.enable_select
				register_kamikaze_action (show_actions, agent on_login)
			end
		end

feature -- Query

	is_submit_successed: BOOLEAN
			-- If bug report submitted successfully

	user_description: STRING_32
			-- Text in `description_text'
		do
			if description_text /= Void then
				Result := description_text.text
			end
		end

feature -- Access

	icon: EV_PIXEL_BUFFER
			-- The dialog's icon
		once
			Result := (create {EV_STOCK_PIXMAPS}).error_pixel_buffer
		end

	title: STRING_32
			-- The dialog's title
		once
			Result := "Submit EiffelStudio Unhandled Exception"
		end

	buttons: DS_SET [INTEGER]
			-- Set of button id's for dialog
			-- Note: Use {ES_DIALOG_BUTTONS} or `dialog_buttons' to determine the id's correspondance.
		once
			Result := dialog_buttons.ok_cancel_buttons
		end

	default_button: INTEGER
			-- The dialog's default action button
		once
			Result := {ES_DIALOG_BUTTONS}.ok_button
		end

	default_confirm_button: INTEGER
			-- The dialog's default confirm button
		once
			Result := {ES_DIALOG_BUTTONS}.ok_button
		end

	default_cancel_button: INTEGER
			-- The dialog's default cancel button
			-- Note: The default cancel button is set on show, so if you want to change the
			--       default cancel button after the dialog has been shown, please see the implmentation
			--       of `show' to see how it is done.
		once
			Result := {ES_DIALOG_BUTTONS}.cancel_button
		end

feature {NONE} -- Implementation: access

	support_url: STRING
			-- Support site url.

	support_login: ESA_SUPPORT_BUG_REPORTER
			-- Reporter used to report bugs to the support system

	remembered_username: STRING_GENERAL
			-- Last remembered user name
		require
			is_interface_usable: is_interface_usable
			is_initialized: is_initialized or is_initializing
			is_user_remembered: is_user_remembered
		do
			if
				attached session_manager.service as l_session_service and then
				attached {STRING_GENERAL} session_data (l_session_service).value (username_session_id) as s
			then
				Result := s
			else
				create {STRING_32} Result.make_empty
			end
		ensure
			result_attached: Result /= Void
		end

	remembered_password: STRING_GENERAL
			-- Last remembered password
		require
			is_interface_usable: is_interface_usable
			is_initialized: is_initialized or is_initializing
			is_user_remembered: is_user_remembered
		do
			if
				attached session_manager.service as l_session_service and then
				attached {STRING_GENERAL} session_data (l_session_service).value (password_session_id) as s
			then
				Result := s
			else
				create {STRING_32} Result.make_empty
			end
		ensure
			result_attached: Result /= Void
		end

	default_description: attached STRING_32
			-- Default text for the bug report description
		do
			if attached last_description as d then
				create Result.make_from_string (d)
			else
				Result := locale_formatter.translation (lb_enter_bug_information)
			end
		end

	last_description: READABLE_STRING_GENERAL
			-- Last description

feature {NONE} -- Status report

	is_user_remembered: BOOLEAN
			-- Indicates if user login information was remembered
		require
			is_interface_usable: is_interface_usable
			is_initialized: is_initialized or is_initializing
		do
			if attached session_manager.service as l_session_service then
				if attached {BOOLEAN_REF} session_data (l_session_service).value_or_default (remembered_session_id, False) as l_ref then
					Result := l_ref.item
				end
			end
		end

	is_synopsis_available: BOOLEAN
			-- Determines if a synopsis has been entered by the user
		require
			is_initialized: is_initialized
			not_is_recycled: not is_recycled
		do
			Result := synopsis_text.text /= Void and then not synopsis_text.text.is_empty and then synopsis_text.text /~ (locale_formatter.translation (lb_enter_synopsis))
		end

	is_description_available: BOOLEAN
			-- Determines if a description has been entered by the user
		require
			is_initialized: is_initialized
			not_is_recycled: not is_recycled
		do
			Result := attached description_text.text as txt and then not txt.is_empty and then
				 not (txt.is_equal (default_description) and last_description = Void)
		end

	can_submit: BOOLEAN
			-- Determines if a report is submittable
		require
			is_initialized: is_initialized
			not_is_recycled: not is_recycled
		do
			Result := support_login.is_support_accessible and then support_login.is_logged_in
		end

feature {NONE} -- Action handlers

	on_login
			-- Called when user requests to log in
		require
			is_initialized: is_initialized
			not_is_recycled: not is_recycled
			is_support_accessible: support_login.is_support_accessible
		do
			on_remember_me_toggled
			execute_with_busy_cursor (agent
				local
					l_error: ES_ERROR_PROMPT
					l_error_info: STRING_32
				do
					login_button.disable_sensitive
					support_login.force_logout
					support_login.attempt_logon (username_text.text, password_text.text, remember_me_check.is_selected)
					if support_login.is_logged_in then
						logged_in_label.set_text ("You are currently logged in as " + username_text.text + " ")
						logged_in_label.show
						log_out_link.show

						login_frame.hide
						create shrink_timer.make_with_interval (shrink_interval)
						shrink_timer.actions.extend (agent on_shrink_interval_expired_for_collapse)
					else
						if support_login.is_bad_request then
							if attached support_login.last_error as ll_error then
								l_error_info := {STRING_32} "Unable to login due to network problem. Please try again later."
								l_error_info.append_character ('%N')
								l_error_info.append (ll_error)
							else
								l_error_info := {STRING_32} "Unable to login due to network problem. Please try again later."
							end
						else
							l_error_info := {STRING_32} "Unable to login with the specified user name and password. Please check and try again."
						end

						create l_error.make_standard (l_error_info)
						l_error.show (dialog)

						logged_in_label.hide
						log_out_link.hide
						login_button.enable_sensitive
						enable_login_content_widget (False)

							-- Set focus back to button, as it will have been the last focused widget
						login_button.set_focus
					end
				end
			)
		end

	on_logout
			-- Called when the user requests a log out of a current session
		require
			is_initialized: is_initialized
			not_is_recycled: not is_recycled
			is_support_accessible: support_login.is_support_accessible
		do
			logged_in_label.hide
			log_out_link.hide

			login_button.enable_sensitive
			enable_login_content_widget (False)
				-- The user wants to change the login, select the user name field
			if username_text.is_displayed then
				username_text.set_focus
			end

			create shrink_timer.make_with_interval (shrink_interval)
			shrink_timer.actions.extend (agent on_shrink_interval_expired_for_expand)
		end

	on_submit
			-- Call when user chooses to submit a bug report when `can_submit'
		require
			is_initialized: is_initialized
			not_is_recycled: not is_recycled
			is_support_accessible: support_login.is_support_accessible
		local
			l_warning: ES_WARNING_PROMPT
			l_error: ES_ERROR_PROMPT
			l_retried: BOOLEAN
		do
			if can_submit then
				if not l_retried then
					if not is_description_available then
						create l_warning.make_standard_with_cancel (locale_formatter.translation (w_no_description))
						l_warning.set_button_action ({ES_DIALOG_BUTTONS}.cancel_button, agent veto_close)
						l_warning.set_button_action ({ES_DIALOG_BUTTONS}.ok_button, agent do execute_with_busy_cursor (agent submit_bug_report) end)
						l_warning.show (dialog)
					else
						is_submit_successed := False
							-- is_submit_successed will be set by `submit_bug_report'
						execute_with_busy_cursor (agent submit_bug_report)
					end
				else
					create l_error.make_standard (locale_formatter.translation (e_submit_error))
					l_error.show (dialog)
				end
			end
		rescue
			l_retried := True
			retry
		end

	on_remember_me_toggled
			-- Called when the user toggles the "remember me" check box.
		require
			is_interface_usable: is_interface_usable
			is_initialized: is_initialized
		local
			l_remember: BOOLEAN
			l_session_data: like session_data
		do
			if attached session_manager.service as l_session_service then
				l_session_data := session_data (l_session_service)
				l_remember := remember_me_check.is_selected
				l_session_data.set_value (l_remember, remembered_session_id)
				if l_remember then
					l_session_data.set_value (username_text.text, username_session_id)
					l_session_data.set_value (password_text.text, password_session_id)
				else
						-- Clear remembered data
					l_session_data.set_value (Void, username_session_id)
					l_session_data.set_value (Void, password_session_id)
				end
					-- Store session information incase user selects to quit ES.
				l_session_service.store (l_session_data)
			end
		end

	on_shrink_interval_expired_for_collapse
			-- Called when `shrink_timer' interval expires when collapsing.
		require
			is_initialized: is_initialized
			not_is_recycled: not is_recycled
			shrink_timer_attached: shrink_timer /= Void
		do
			-- On Solaris, minimum height of `shrink_widget' is 1, not 0.
			-- On Windows, minimum height of `shrink_widget' is 0.
			if shrink_widget.height <= 1 then
				shrink_widget.set_minimum_height (0)
				shrink_timer.destroy
				shrink_timer := Void
				enable_login_content_widget (True)

					-- Set focus to description, now the fields are activated
				description_text.set_focus
			else
				shrink_widget.set_minimum_height ((shrink_widget.height - 4).max (0))
			end
		end

	on_shrink_interval_expired_for_expand
			-- Called when `shrink_timer' interval expires when expanding.
		require
			is_initialized: is_initialized
			not_is_recycled: not is_recycled
			shrink_timer_attached: shrink_timer /= Void
		do
			if shrink_widget.height = login_frame.height then
				shrink_timer.destroy
				shrink_timer := Void
				enable_login_content_widget (False)
				login_frame.show
			else
				shrink_widget.set_minimum_height ((shrink_widget.height + 4).min (login_frame.height))
			end
		end

	on_text_component_focused (a_text_widget: EV_TEXT_COMPONENT)
			-- Called when a registered text widget attains focused
			--
			-- `a_text_widget': The focused text_widget.
		require
			is_initialized: is_initialized or is_initializing
			not_is_recycled: not is_recycled
			a_text_widget_attached: a_text_widget /= Void
		local
			l_text: STRING_GENERAL
		do
			l_text := a_text_widget.text
			if l_text = Void or else l_text.is_case_insensitive_equal (default_description) then
				a_text_widget.set_foreground_color (colors.grid_item_text_color)
				if a_text_widget /= description_text or else last_description = Void then
					a_text_widget.remove_text
				end
			end
		end

	on_text_component_focused_out (a_text_widget: EV_TEXT_COMPONENT; a_default_text: READABLE_STRING_GENERAL)
			-- Called when a registered text widget loses focused
			--
			-- `a_text_widget': The unfocused text_widget.
			-- `a_default_text': The default text to show, if no text is available for the widget.
		require
			is_initialized: is_initialized or is_initializing
			not_is_recycled: not is_recycled
			a_text_widget_attached: a_text_widget /= Void
			a_default_text_attached: a_default_text /= Void
			not_a_default_text_is_empty: not a_default_text.is_empty
		local
			l_text: STRING_GENERAL
		do
			l_text := a_text_widget.text
			if l_text = Void or else l_text.is_empty then
				a_text_widget.set_foreground_color (colors.grid_disabled_item_text_color)
				a_text_widget.set_text (a_default_text)
			end
		end

	on_focus_in
			-- When the `description_text' has the focus, we disable the default push button.
		local
			l_dialog: EV_DIALOG
		do
			l_dialog := dialog
			if l_dialog /= Void and then
				(not l_dialog.is_destroyed and l_dialog.default_push_button /= Void) then
				l_dialog.remove_default_push_button
			end
		end

	on_focus_out
			-- When the `description_text' lost focus, we enable the default push button.
		local
			l_dialog: EV_DIALOG
			l_button: EV_BUTTON
		do
			l_dialog := dialog
			if l_dialog /= Void then
			l_button := dialog_window_buttons.item (default_button)
				if l_button /= Void and then
				 (not l_dialog.is_destroyed and l_dialog.has_recursive (l_button)) then
					l_dialog.set_default_push_button (l_button)
				end
			end
		end

	on_password_key_pressed (a_key: EV_KEY)
			-- When user pressed a key in `password_text'
		do
			if a_key /= Void and then a_key.code = {EV_KEY_CONSTANTS}.key_enter and then login_button.is_sensitive then
				on_login
			end
		end

feature {NONE} -- User interface manipulation

	enable_login
			-- Enable login
		require
			is_initialized: is_initialized or is_initializing
			not_is_recycled: not is_recycled
			login_button_attached: login_button /= Void
			remember_me_check_attached: remember_me_check /= Void
		do
			if username_text.text.count >= 6 and then password_text.text.count >= 4 then
				login_button.enable_sensitive
				remember_me_check.enable_sensitive
			else
				login_button.disable_sensitive
				remember_me_check.disable_sensitive
			end
		end

	enable_login_content_widget (a_enable: BOOLEAN)
			-- Enable/disable login context wdigets based on login state
		require
			is_initialized: is_initialized or is_initializing
			not_is_recycled: not is_recycled
			login_frame_attached: login_frame /= Void
		do
			if a_enable then
				login_frame.disable_sensitive
				enable_report_frame_widgets

				if can_submit then
					dialog_window_buttons.item ({ES_DIALOG_BUTTONS}.ok_button).enable_sensitive
				else
					dialog_window_buttons.item ({ES_DIALOG_BUTTONS}.ok_button).disable_sensitive
				end
			else
				login_frame.enable_sensitive
				disable_report_frame_widgets

				dialog_window_buttons.item ({ES_DIALOG_BUTTONS}.ok_button).disable_sensitive
			end
		end

	disable_report_frame_widgets
			-- We want all widgets looks like disabled, so users can copy the title in the `synopsis_text' without login
			-- See bug#15066
		do
			-- FIXIT: We should fix {ES_COLORS}.disabled_foreground_color to REAL theme color
			report_frame.set_foreground_color (colors.disabled_foreground_color)

			synopsis_text.enable_sensitive
			synopsis_text.disable_edit
			synopsis_text.set_foreground_color (colors.disabled_foreground_color)

			description_text.disable_sensitive
			make_public_check.disable_sensitive
			severity_label.disable_sensitive
			severity_critical_radio.disable_sensitive
			severity_serious_radio.disable_sensitive
			severity_non_critical_radio.disable_sensitive
		end

	enable_report_frame_widgets
			-- Correspond to `disable_report_frame_widgets'
			-- We retore widgets' "sensitive" here
		local
			l_color: EV_STOCK_COLORS
		do
			create l_color

			report_frame.set_foreground_color (l_color.default_foreground_color)

			synopsis_text.enable_sensitive
			synopsis_text.enable_edit
			synopsis_text.set_foreground_color (l_color.default_foreground_color)

			description_text.enable_sensitive
			make_public_check.enable_sensitive
			severity_label.enable_sensitive
			severity_critical_radio.enable_sensitive
			severity_serious_radio.enable_sensitive
			severity_non_critical_radio.enable_sensitive
		end

feature {NONE} -- User interface elements

	login_frame: EV_FRAME
			-- Login container frame

	logged_in_label: EV_LABEL
			-- Logged in message label

	severity_label: EV_LABEL
				-- Severity label

	log_out_link: EV_LINK_LABEL
			-- Logged in message lable link to log ou

	username_text: EV_TEXT_FIELD
			-- Login username

	password_text: EV_PASSWORD_FIELD
			-- Login password

	remember_me_check: EV_CHECK_BUTTON
			-- Login remember me

	login_button: EV_BUTTON
			-- Login button

	report_frame: EV_FRAME
			-- Bug report container frame

	synopsis_text: EV_TEXT_FIELD
			-- Report synopsis

	description_text: EV_TEXT
			-- Report description

	make_public_check: EV_CHECK_BUTTON
			-- Report privacy option

	shrink_timer: EV_TIMEOUT
			-- Timer used to perform shrinking of login widgets

	shrink_interval: INTEGER = 3
			-- Default shink interval

	shrink_widget: EV_FIXED
			-- Shrink widget used to perform shinking

	severity_critical_radio: EV_RADIO_BUTTON
			-- Severity critical radio button

	severity_serious_radio: EV_RADIO_BUTTON
			-- Severity serious radio button

	severity_non_critical_radio: EV_RADIO_BUTTON
			-- Severity non-critical radio button

feature {NONE} -- Reporting

	synopsis: STRING_32
			-- Synopsis text
		require
			is_initialized: is_initialized or is_initializing
			not_is_recycled: not is_recycled
		local
			l_class_name: STRING
			l_recipient: STRING
			l_exceptions: EXCEPTIONS
			l_exception_tag: like {EXCEPTION}.tag
			l_exception_code: INTEGER_32
			l_description: like {EXCEPTION}.description
			l_exception: EXCEPTION
		do
			create Result.make (100)

			if not is_initialized or else not is_synopsis_available then
				create l_exceptions
				l_exception := l_exceptions.exception_manager.last_exception
				if l_exception /= Void then
					l_exception_tag := l_exception.original.tag
					l_exception_code := l_exception.original.code
				end
				if l_exception_tag = Void then
					l_exception_tag := {STRING_32} " " + l_exception_code.out + " Unknown exception code"
				end
				Result.append_string_general (l_exception_tag)
				Result.prune_all_trailing ('.')
				Result.append_character (' ')

				if l_exceptions.assertion_violation then
					Result.append ("Tag: ")
					if l_exception /= Void then
						l_description := l_exception.original.description
					end
					if l_description = Void then
						l_description := "unknown tag name"
					end
					Result.append_string_general (l_description)
					Result.append_character (' ')
				end

				if l_exception /= Void then
					l_class_name := l_exception.original.type_name
				end
				if l_class_name /= Void then
					Result.append ("in {")
					Result.append (l_class_name)
					Result.append_character ('}')
					l_recipient := l_exception.original.recipient_name
					if l_recipient /= Void then
						Result.append_character ('.')
						Result.append (l_recipient)
					end
				end
				Result.append (" in ")
				Result.append (workbench_name)
				Result.append_character ('.')
			else
				Result.append (synopsis_text.text)
			end
		ensure
			result_attached: Result /= Void
			not_result_is_empty: not Result.is_empty
		end

	description: STRING_32
			-- Description text
		require
			is_initialized: is_initialized or is_initializing
			not_is_recycled: not is_recycled
		local
			l_trace: STRING
			l_exceptions: EXCEPTIONS
		do
			create Result.make (512)
			if is_initialized and then is_description_available then
				Result.append (description_text.text)
				Result.prune_all_trailing ('%N')
				Result.append ("%N%N")
			end

			create l_exceptions
			l_trace := l_exceptions.exception_trace
			Result.append (l_trace)
		ensure
			result_attached: Result /= Void
			not_result_is_empty: not Result.is_empty
		end

	submit_bug_report
			-- Submits a bug report.
		require
			is_initialized: is_initialized
			not_is_recycled: not is_recycled
			support_login_is_logged_in: support_login.is_logged_in
		local
			l_report: ESA_SUPPORT_BUG_REPORT
			l_thanks: ES_INFORMATION_PROMPT
			l_error: ES_ERROR_PROMPT
			l_transistion: ES_POPUP_TRANSITION_WINDOW
			l_window: EV_WINDOW
			retried: BOOLEAN
		do
			if not retried then
				create l_transistion.make_with_icon (locale_formatter.translation (lb_submitting), stock_pixmaps.tool_output_failed_icon_buffer)
				l_window := dialog
				check l_window_attached: l_window /= Void end
				l_transistion.show_relative_to_window (l_window)

				create l_report.make (synopsis, description, compiler_version_number.version)
				l_report.environment := workbench_name + " " + version_number
				l_report.to_reproduce := "Please see description"
				l_report.confidential := not make_public_check.is_selected
				if severity_critical_radio.is_selected then
					l_report.severity := l_report.severity_critical
				elseif severity_non_critical_radio.is_selected then
					l_report.severity := l_report.severity_non_critical
				else
					check severity_serious_radio.is_selected end
					l_report.severity := l_report.severtiy_serious
				end

				support_login.report_bug (l_report)
				l_transistion.hide

				if support_login.is_bad_request then
					if attached support_login.last_error as ll_error then
						create l_error.make_standard ("Unable to submit bug report due to network problem. Please try again later.%N" + ll_error)
					else
						create l_error.make_standard ("Unable to submit bug report due to network problem. Please try again later.")
					end
					l_error.show (dialog)
				else
					create l_thanks.make_standard (locale_formatter.translation (lb_submitted))
					l_thanks.set_sub_title (locale_formatter.translation (tt_thank_you))
					l_thanks.show (dialog)
					is_submit_successed := True
				end
			else
				if attached l_transistion and then l_transistion.is_shown then
						-- Need to hide the transition window if there was a failure.
					l_transistion.hide
				end
				create l_error.make_standard (locale_formatter.translation (e_submit_error))
				l_error.show (dialog)
				is_submit_successed := False
					-- Do not close the submit dialog when error occurs
					-- this way the user can try again
				is_close_vetoed := True
			end
		rescue
			retried := True
			retry
		end

feature {NONE} -- Internationalization


	t_account_access: STRING = "Account Access"
	t_bug_information: STRING = "Bug Information"

	tt_thank_you: STRING = "Thank you for the bug report"

	lb_enter_bug_information: STRING = "Enter supplementary bug information"
	lb_enter_synopsis: STRING = "Enter synopsis"
	lb_make_public: STRING = "Make bug publicly available"
	lb_password: STRING = "Password:"
	lb_remember_me: STRING = "Remember me"
	lb_severity: STRING = "Severity:"
	lb_submitted: STRING
		once
			Result := "The submitted report is now available at "
			Result.append (support_url)
		end

	lb_submitting: STRING = "Submitting bug report, please wait..."
	lb_register_account: STRING = "If you do not already have an account, please register "
	lb_username: STRING = "Username:"

	b_here: STRING = "here"
	b_login: STRING = "Login"
	b_log_out: STRING = "Log out"
	b_submit: STRING = "Submit"

	i_critical: STRING = "Critical"
	i_serious: STRING = "Serious"
	i_non_critical: STRING = "Non Critical"

	w_no_description: STRING = "No bug description has been supplied. Submitting a report without additional details can make it hard to reproduce.%N%NDo you want to continue submitting a bug report?"
	e_submit_error: STRING
		once
			Result := "There was a problem submitting the problem report. Please retry or submit it manually at "
			Result.append (support_url)
		end

feature {NONE} -- Constants

	username_session_id: STRING_8 = "com.eiffel.exception_submit_dialog.username"
	password_session_id: STRING_8 = "com.eiffel.exception_submit_dialog.password"
	remembered_session_id: STRING_8 = "com.eiffel.exception_submit_dialog.remembered"


invariant
	support_reporter: support_login /= Void
	login_frame_attached: (is_initialized and not is_recycled) implies login_frame /= Void
	logged_in_label_attached: (is_initialized and not is_recycled) implies logged_in_label /= Void
	log_out_link_attached: (is_initialized and not is_recycled) implies log_out_link /= Void
	username_text_attached: (is_initialized and not is_recycled) implies username_text /= Void
	password_text_attached: (is_initialized and not is_recycled) implies password_text /= Void
	remember_me_check_attached: (is_initialized and not is_recycled) implies remember_me_check /= Void
	login_button_attached: (is_initialized and not is_recycled) implies login_button /= Void
	report_frame_attached: (is_initialized and not is_recycled) implies report_frame /= Void
	synopsis_text_attached: (is_initialized and not is_recycled) implies synopsis_text /= Void
	more_info_text_attached: (is_initialized and not is_recycled) implies description_text /= Void
	make_public_check_attached: (is_initialized and not is_recycled) implies make_public_check /= Void
	shrink_timer_attached: (is_initialized and not is_recycled) implies shrink_timer /= Void
	shrink_widget_attached: (is_initialized and not is_recycled) implies shrink_widget /= Void
	shrink_interval_positive: shrink_interval > 0

;note
	copyright: "Copyright (c) 1984-2020, Eiffel Software"
	license:   "GPL version 2 (see http://www.eiffel.com/licensing/gpl.txt)"
	licensing_options: "http://www.eiffel.com/licensing"
	copying: "[
			This file is part of Eiffel Software's Eiffel Development Environment.
			
			Eiffel Software's Eiffel Development Environment is free
			software; you can redistribute it and/or modify it under
			the terms of the GNU General Public License as published
			by the Free Software Foundation, version 2 of the License
			(available at the URL listed under "license" above).
			
			Eiffel Software's Eiffel Development Environment is
			distributed in the hope that it will be useful, but
			WITHOUT ANY WARRANTY; without even the implied warranty
			of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
			See the GNU General Public License for more details.
			
			You should have received a copy of the GNU General Public
			License along with Eiffel Software's Eiffel Development
			Environment; if not, write to the Free Software Foundation,
			Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
		]"
	source: "[
			Eiffel Software
			5949 Hollister Ave., Goleta, CA 93117 USA
			Telephone 805-685-1006, Fax 805-685-6869
			Website http://www.eiffel.com
			Customer support http://support.eiffel.com
		]"

end
