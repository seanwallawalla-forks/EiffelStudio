note
	description: "API to handle ES Cloud api."
	date: "$Date$"
	revision: "$Revision$"

class
	ES_CLOUD_API

inherit
	ES_CLOUD_ACCOUNT_API_I

	ES_CLOUD_SUBSCRIPTION_API_I

	CMS_MODULE_API
		rename
			make as make_api
		redefine
			initialize
		end

	REFACTORING_HELPER

create
	make

feature {NONE} -- Initialization

	make (a_module: ES_CLOUD_MODULE; a_api: CMS_API)
		do
			module := a_module
			cms_api := a_api
			initialize
		end

	initialize
			-- <Precursor>
		do
			Precursor
			create config.make
			if attached cms_api.module_configuration_by_name ({ES_CLOUD_MODULE}.name, "config") as cfg then
				if attached cfg.resolved_text_item ("api.secret") as s then
					config.set_api_secret (s)
				end

				if attached cfg.resolved_text_item ("session.expiration_delay") as s then
					config.session_expiration_delay := s.to_integer
				end
				if
					attached cfg.resolved_text_item ("license.auto_trial") as s and then
					s.is_case_insensitive_equal_general ("yes")
				then
					config.enable_auto_trial (cfg.resolved_text_item ("license.auto_trial_plan"))
				end
			end

				-- Storage initialization
			if attached cms_api.storage.as_sql_storage as l_storage_sql then
				create {ES_CLOUD_STORAGE_SQL} es_cloud_storage.make (l_storage_sql)
			else
					-- FIXME: in case of NULL storage, should Current be disabled?
				create {ES_CLOUD_STORAGE_NULL} es_cloud_storage
			end
		end

feature {CMS_MODULE} -- Access nodes storage.

	es_cloud_storage: ES_CLOUD_STORAGE_I

feature -- Settings

	module: ES_CLOUD_MODULE

	config: ES_CLOUD_CONFIG

feature -- Access

	active_user: detachable ES_CLOUD_USER
		do
			if attached cms_api.user as u then
				create Result.make (u)
			end
		end

	plans: LIST [ES_CLOUD_PLAN]
		do
			Result := es_cloud_storage.plans
		end

	sorted_plans: LIST [ES_CLOUD_PLAN]
		do
			Result := plans
			plans_sorter.sort (Result)
		end

	plans_sorter: SORTER [ES_CLOUD_PLAN]
		local
			comp: AGENT_EQUALITY_TESTER [ES_CLOUD_PLAN]
		do
			create comp.make (agent (u,v: ES_CLOUD_PLAN): BOOLEAN
					do
						if u.weight /= v.weight then
							Result := u.weight < v.weight
						elseif attached u.name as u_name then
							if attached v.name as v_name then
								Result := u_name < v_name
							else
								Result := True
							end
						else
							Result := u.id < v.id
						end
					end
				)
			create {QUICK_SORTER [ES_CLOUD_PLAN]} Result.make (comp)
		end

	default_plan: detachable ES_CLOUD_PLAN
		do
			if attached sorted_plans as lst and then not lst.is_empty then
				Result := lst.first
			end
		end

	plan (a_plan_id: INTEGER): detachable ES_CLOUD_PLAN
		do
			Result := es_cloud_storage.plan (a_plan_id)
		end

	plan_by_name (a_name: READABLE_STRING_GENERAL): detachable ES_CLOUD_PLAN
		do
			across
				plans as ic
			until
				Result /= Void
			loop
				Result := ic.item
				if not a_name.is_case_insensitive_equal (Result.name) then
					Result := Void
				end
			end
		end

feature -- Access: licenses

	licenses: LIST [TUPLE [license: ES_CLOUD_LICENSE; user: detachable ES_CLOUD_USER; email: detachable READABLE_STRING_8; org: detachable ES_CLOUD_ORGANIZATION]]
			-- Licenses
		do
			Result := es_cloud_storage.licenses
		end

	licenses_for_plan (a_plan: ES_CLOUD_PLAN): like licenses
		do
			Result := es_cloud_storage.licenses_for_plan (a_plan)
		end

	license (a_license_id: INTEGER_64): detachable ES_CLOUD_LICENSE
		do
			Result := es_cloud_storage.license (a_license_id)
		end

	license_by_key (a_license_key: READABLE_STRING_GENERAL): detachable ES_CLOUD_LICENSE
		do
			Result := es_cloud_storage.license_by_key (a_license_key)
		end

	user_for_license (a_license: ES_CLOUD_LICENSE): detachable ES_CLOUD_USER
		local
			uid: INTEGER_64
		do
			uid := es_cloud_storage.user_id_for_license (a_license)
			if uid /= 0 and then attached cms_api.user_api.user_by_id (uid) as u then
				create Result.make (u)
			end
		end

	user_has_license (a_user: ES_CLOUD_USER; a_license_id: INTEGER_64): BOOLEAN
		do
			Result := es_cloud_storage.user_has_license (a_user, a_license_id)
		end

	user_licenses (a_user: ES_CLOUD_USER): LIST [ES_CLOUD_USER_LICENSE]
		do
			Result := es_cloud_storage.user_licenses (a_user)
		end

	email_for_license (a_license: ES_CLOUD_LICENSE): detachable READABLE_STRING_8
		do
			Result := es_cloud_storage.email_for_license (a_license)
		end

	email_license (a_license: ES_CLOUD_LICENSE): detachable ES_CLOUD_EMAIL_LICENSE
		do
			Result := es_cloud_storage.email_license (a_license)
		end

	email_licenses (a_email: READABLE_STRING_8): LIST [ES_CLOUD_EMAIL_LICENSE]
		do
			Result := es_cloud_storage.email_licenses (a_email)
		end

feature -- Access trial		

	trial_user_licenses (a_user: ES_CLOUD_USER): detachable ARRAYED_LIST [ES_CLOUD_USER_LICENSE]
			-- Existing trial license for user `a_user` or email `a_email` if any.
		local
			lic: ES_CLOUD_USER_LICENSE
		do
			if attached trial_plan as pl then
				create Result.make (1)
				across
					user_licenses (a_user) as ic
				loop
					lic := ic.item
					if pl.same_plan (lic.license.plan) then
						Result.force (lic)
					end
				end
			end
		end

	trial_plan: detachable ES_CLOUD_PLAN
		do
			if config.auto_trial_enabled then
				if attached config.auto_trial_plan_name as pl_name then
					Result := plan_by_name (pl_name)
				end
				if Result = Void then
					Result := default_plan
				end
			end
		end

feature -- Element change license

	auto_assign_trial_to (a_user: ES_CLOUD_USER)
		local
			pl: ES_CLOUD_PLAN
			lic: ES_CLOUD_LICENSE
		do
			if config.auto_trial_enabled then
				if attached config.auto_trial_plan_name as pl_name then
					pl := plan_by_name (pl_name)
				end
				if pl = Void then
					pl := default_plan
				end
				if pl /= Void then
					lic := new_license_for_plan (pl)
					lic.set_remaining_days (pl.trial_period_in_days)
					save_new_license (lic, a_user)
					if
						attached a_user.cms_user as l_cms_user and then
						attached l_cms_user.email as l_email
					then
						if l_email /= Void then
							send_new_license_mail (l_cms_user, l_cms_user.profile_name, l_email, lic, Void, Void)
						end
						notify_new_license (l_cms_user, l_cms_user.profile_name, l_email, lic, Void)
					end
				end
			end
		end

	new_license_for_plan (a_plan: ES_CLOUD_PLAN): ES_CLOUD_LICENSE
		local
			k: STRING_32
		do
			k := cms_api.new_random_identifier (16, once "ABCDEFGHJKMNPQRSTUVW23456789") -- Without I O L 0 1 , which are sometime hard to distinguish!
			create Result.make (k, a_plan)
			es_cloud_storage.save_license (Result)
		end

	extend_license_with_duration (lic: ES_CLOUD_LICENSE; nb_years, nb_months, nb_days: INTEGER)
			-- Extend the license `lic` life duration by
			--  `nb_years` year(s)
			--  `nb_months` month(s)
			--  `nb_days` day(s)
		local
			dt: DATE_TIME
			d: DATE
			y,mo: INTEGER
			orig: DATE_TIME
		do
			orig := lic.expiration_date
			if orig = Void then
				orig := lic.creation_date
				create orig.make_by_date_time (orig.date, orig.time)
				if lic.days_remaining > 0 then
					orig.day_add (lic.days_remaining)
				end
			end
			create dt.make_by_date_time (orig.date, orig.time)
			y := dt.year + nb_years
			mo := dt.month + nb_months
			if mo > 12 then
				y := y + mo // 12
				mo := mo \\ 12
			end
			create d.make (y, mo, dt.day)
			d.day_add (nb_days)
			create dt.make_by_date_time (d, dt.time)
			lic.set_expiration_date (dt)
		end

	save_new_license (a_license: ES_CLOUD_LICENSE; a_user: detachable ES_CLOUD_USER)
		do
			es_cloud_storage.save_license (a_license)
			if a_user /= Void then
				assign_license_to_user (a_license, a_user)
			end
		end

	save_license (a_license: ES_CLOUD_LICENSE)
		do
			es_cloud_storage.save_license (a_license)
		end

	update_license (a_license: ES_CLOUD_LICENSE; a_user: detachable ES_CLOUD_USER)
		require
			existing_license: license (a_license.id) /= Void
		do
			if a_user /= Void and then not user_has_license (a_user, a_license.id) then
				assign_license_to_user (a_license, a_user)
			end
			es_cloud_storage.save_license (a_license)
		end

	discard_license (a_license: ES_CLOUD_LICENSE)
		require
			existing_license: license (a_license.id) /= Void
		do
			-- FIXME: to implement!
		end

	suspend_license (a_license: ES_CLOUD_LICENSE)
		require
			existing_license: license (a_license.id) /= Void
		do
			a_license.suspend
			es_cloud_storage.save_license (a_license)
		end

	resume_license (a_license: ES_CLOUD_LICENSE)
		require
			existing_license: license (a_license.id) /= Void
			is_suspended: a_license.is_suspended
		do
			a_license.resume
			es_cloud_storage.save_license (a_license)
		end

	assign_license_to_user (a_license: ES_CLOUD_LICENSE; a_user: ES_CLOUD_USER)
		do
			es_cloud_storage.assign_license_to_user (a_license, a_user)
		end

	move_email_license_to_user (a_email_license: ES_CLOUD_EMAIL_LICENSE; a_user: ES_CLOUD_USER)
		do
			es_cloud_storage.move_email_license_to_user (a_email_license, a_user)
		end

	assign_license_to_email (a_license: ES_CLOUD_LICENSE; a_email: READABLE_STRING_8)
		do
			es_cloud_storage.assign_license_to_email (a_license, a_email)
		end

	converted_license_from_user_subscription (a_sub: ES_CLOUD_PLAN_SUBSCRIPTION; a_installation: detachable ES_CLOUD_INSTALLATION): detachable ES_CLOUD_LICENSE
		local
			inst: ES_CLOUD_INSTALLATION
		do
			if attached {ES_CLOUD_PLAN_USER_SUBSCRIPTION} a_sub as sub then
				Result := new_license_for_plan (sub.plan)
				Result.set_creation_date (sub.creation_date)
				if attached sub.expiration_date as exp then
					Result.set_expiration_date (exp)
				else
					Result.set_remaining_days (sub.plan.trial_period_in_days)
				end
				if a_installation /= Void then
					Result.set_platforms_restriction (a_installation.platform)
					Result.set_version (a_installation.product_version)
				end
				save_new_license (Result, sub.user)
				es_cloud_storage.discard_user_subscription (sub)
					-- HACK: previously installation tables included the uid, now we have license id `lid`
				if attached es_cloud_storage.license_installations (sub.user_id) as lst then
					across
						lst as ic
					loop
						inst := ic.item
						inst.update_license_id (Result.id)
						es_cloud_storage.save_installation (inst)
					end
				end
				if
					attached sub.user.cms_user as l_cms_user and then
					attached l_cms_user.email as l_email
				then
					if l_email /= Void then
						send_new_license_mail (l_cms_user, l_cms_user.profile_name, l_email, Result, Void, Void)
					end
					notify_new_license (l_cms_user, l_cms_user.profile_name, l_email, Result, Void)
				end
			end
		end

feature -- License subscription

	subscribed_licenses (a_order_ref: READABLE_STRING_GENERAL): detachable LIST [ES_CLOUD_LICENSE]
		do
			Result := es_cloud_storage.subscribed_licenses (a_order_ref)
		end

	record_yearly_license_subscription (a_license: ES_CLOUD_LICENSE; a_sub_ref: detachable READABLE_STRING_GENERAL)
		local
			sub: ES_CLOUD_LICENSE_SUBSCRIPTION
		do
			create sub.make_yearly (a_license)
			if a_sub_ref /= Void then
				sub.set_subscription_reference (a_sub_ref)
			end
			es_cloud_storage.save_license_subscription (sub)
		end

	record_monthly_license_subscription (a_license: ES_CLOUD_LICENSE; a_sub_ref: detachable READABLE_STRING_GENERAL)
		local
			sub: ES_CLOUD_LICENSE_SUBSCRIPTION
		do
			create sub.make_monthly (a_license)
			if a_sub_ref /= Void then
				sub.set_subscription_reference (a_sub_ref)
			end
			es_cloud_storage.save_license_subscription (sub)
		end

	record_weekly_license_subscription (a_license: ES_CLOUD_LICENSE; a_sub_ref: detachable READABLE_STRING_GENERAL)
		local
			sub: ES_CLOUD_LICENSE_SUBSCRIPTION
		do
			create sub.make_weekly (a_license)
			if a_sub_ref /= Void then
				sub.set_subscription_reference (a_sub_ref)
			end
			es_cloud_storage.save_license_subscription (sub)
		end

	record_daily_license_subscription (a_license: ES_CLOUD_LICENSE; a_sub_ref: detachable READABLE_STRING_GENERAL)
		local
			sub: ES_CLOUD_LICENSE_SUBSCRIPTION
		do
			create sub.make_daily (a_license)
			if a_sub_ref /= Void then
				sub.set_subscription_reference (a_sub_ref)
			end
			es_cloud_storage.save_license_subscription (sub)
		end

	record_onetime_license_payment (a_license: ES_CLOUD_LICENSE; a_nb_months: NATURAL_32; a_payment_ref: detachable READABLE_STRING_GENERAL)
		local
			sub: ES_CLOUD_LICENSE_SUBSCRIPTION
		do
			create sub.make (a_license, {ES_CLOUD_LICENSE_SUBSCRIPTION}.onetime, a_nb_months)
			if a_payment_ref /= Void then
				sub.set_payment_reference (a_payment_ref)
			end
			es_cloud_storage.save_license_subscription (sub)
		end

feature -- Billings

	license_billings (a_license: ES_CLOUD_LICENSE): detachable SHOPPING_BILLS
		do
			if
				attached es_cloud_storage.license_subscription (a_license) as l_sub and then
				attached l_sub.subscription_reference as ref
			then
				if
					attached {SHOP_MODULE} cms_api.module ({SHOP_MODULE}) as l_shop_module and then
					attached l_shop_module.shop_api as l_shop_api
				then
					Result := l_shop_api.billings (ref)
				end
			end
		end

feature -- Access: store

	store (a_currency: detachable READABLE_STRING_8): ES_CLOUD_STORE
		local
			l_item: ES_CLOUD_STORE_ITEM
			l_cents: NATURAL_32
			l_visible: BOOLEAN
		do
			Result := internal_store (a_currency)
			if Result = Void then
				if a_currency = Void then
					create Result.make
				else
					create Result.make_with_currency (a_currency)
				end
				if attached cms_api.module_configuration_by_name ({ES_CLOUD_MODULE}.name, "store-" + Result.currency) as cfg then
					set_internal_store (Result)
					if attached cfg.table_keys ("") as lst then
						across
							lst as ic
						loop
							if
								attached cfg.text_table_item (ic.item) as tb and then
								attached tb.item ("plan") as l_plan and then
								attached tb.item ("price") as l_price and then
								attached tb.item ("currency") as l_currency
							then
								if attached tb.item ("status") as l_status then
									if
										l_status.is_case_insensitive_equal ("published")
									then
										l_visible := True
									else
										l_visible := False
									end
								else
									l_visible := True
								end
								if l_visible then
									if attached tb.item ("price.cents") as l_cents_price then
										l_cents := l_cents_price.to_natural_32
									else
										l_cents := 0
									end
									create l_item.make (ic.item)
									l_item.set_price (l_price.to_natural_32, l_cents, l_currency.to_string_8, tb.item ("interval"))
									l_item.set_title (tb.item ("title"))
									l_item.set_price_title (tb.item ("price.title"))
									l_item.set_name (l_plan)
									if
										l_item.is_onetime and then
										attached tb.item ("duration") as l_duration and then
										l_duration.is_natural_32
									then
										l_item.set_onetime_month_duration (l_duration.to_natural_32)
									end
									Result.extend (l_item)
								end
							end
						end
					end
				end
			end
		end

	internal_store (a_currency: detachable READABLE_STRING_8): detachable ES_CLOUD_STORE
		local
			l_currency: READABLE_STRING_8
		do
			l_currency := a_currency
			if l_currency = Void then
				l_currency := {ES_CLOUD_STORE}.default_currency
			end
			if attached internal_store_by_currency as tb then
				Result := tb.item (l_currency)
			end
		end

	set_internal_store (a_store: ES_CLOUD_STORE)
		local
			tb: like internal_store_by_currency
		do
			tb := internal_store_by_currency
			if tb = Void then
				create tb.make_caseless (1)
				internal_store_by_currency := tb
			end
			tb [a_store.currency] := a_store
		end

	internal_store_by_currency: detachable STRING_TABLE [ES_CLOUD_STORE]

feature -- Access: subscriptions

	default_concurrent_sessions_limit: NATURAL = 1
	 		-- Default, a unique concurrent session!

	default_heartbeat: NATURAL = 900 -- 15 * 60
	 		-- Default heartbeat in seconds	 		

	user_concurrent_sessions_limit (a_user: ES_CLOUD_USER): NATURAL
		do
			if attached user_subscription (a_user) as l_plan_sub then
				Result := l_plan_sub.concurrent_sessions_limit
			else
				Result := default_concurrent_sessions_limit
			end
		end

	discard_installation (inst: ES_CLOUD_INSTALLATION; a_user: detachable ES_CLOUD_USER)
		do
			es_cloud_storage.discard_installation (inst, a_user)
		end

	all_user_installations: LIST [ES_CLOUD_INSTALLATION]
		do
			Result := es_cloud_storage.all_user_installations
			user_installations_sorter.reverse_sort (Result)
		end

	user_installations (a_user: ES_CLOUD_USER): LIST [ES_CLOUD_INSTALLATION]
		do
			Result := es_cloud_storage.user_installations (a_user)
			user_installations_sorter.reverse_sort (Result)
		end

	installation (a_install_id: READABLE_STRING_GENERAL): detachable ES_CLOUD_INSTALLATION
		do
			Result := es_cloud_storage.installation (a_install_id)
		end

	license_installations (a_license: ES_CLOUD_LICENSE): LIST [ES_CLOUD_INSTALLATION]
		do
			Result := es_cloud_storage.license_installations (a_license.id)
		end

	user_installations_sorter: SORTER [ES_CLOUD_INSTALLATION]
		local
			comp: AGENT_EQUALITY_TESTER [ES_CLOUD_INSTALLATION]
		do
			create comp.make (agent (u,v: ES_CLOUD_INSTALLATION): BOOLEAN
					do
						if attached u.creation_date as u_cd then
							if attached v.creation_date as v_cd then
								Result := u_cd < v_cd
							else
								Result := u.id < v.id
							end
						elseif v.creation_date /= Void then
							Result := True
						else
							Result := u.id < v.id
						end
					end
				)
			create {QUICK_SORTER [ES_CLOUD_INSTALLATION]} Result.make (comp)
		end

	last_user_session (a_user: ES_CLOUD_USER; a_installation: detachable ES_CLOUD_INSTALLATION): detachable ES_CLOUD_SESSION
			-- Last user session, and only for installation `a_installation` is provided.
		do
			Result := es_cloud_storage.last_user_session (a_user, a_installation)
		end

	last_license_session (a_license: ES_CLOUD_LICENSE): detachable ES_CLOUD_SESSION
		do
			Result := es_cloud_storage.last_license_session (a_license)
		end

	user_session (a_user: ES_CLOUD_USER; a_install_id, a_session_id: READABLE_STRING_GENERAL): detachable ES_CLOUD_SESSION
		do
			Result := es_cloud_storage.user_session (a_user, a_install_id, a_session_id)
		end

	user_sessions (a_user: ES_CLOUD_USER; a_install_id: detachable READABLE_STRING_GENERAL; a_only_active: BOOLEAN): detachable LIST [ES_CLOUD_SESSION]
		do
			Result := es_cloud_storage.user_sessions (a_user, a_install_id, a_only_active)
			if Result /= Void then
				user_session_sorter.reverse_sort (Result)
			end
		end

	installation_sessions (a_install_id: READABLE_STRING_GENERAL; a_only_active: BOOLEAN): detachable LIST [ES_CLOUD_SESSION]
		do
			Result := es_cloud_storage.installation_sessions (a_install_id, a_only_active)
			if Result /= Void then
				user_session_sorter.reverse_sort (Result)
			end
		end

	user_active_concurrent_sessions (a_user: ES_CLOUD_USER; a_install_id: READABLE_STRING_GENERAL; a_current_session: ES_CLOUD_SESSION): detachable STRING_TABLE [LIST [ES_CLOUD_SESSION]]
			-- Active sessions indexed by installation id.
		local
			l_session: ES_CLOUD_SESSION
			lst, lst_by_installation: like user_sessions
		do
			lst := user_sessions (a_user, Void, True)
			if lst /= Void then
				from
					lst.start
				until
					lst.off
				loop
					l_session := lst.item
					if
						l_session.is_paused or else
						a_current_session.same_as (l_session) or else
						a_current_session.installation_id.same_string (l_session.installation_id)
					then
						lst.remove
					else
						lst.forth
					end
				end
				if lst.is_empty then
					lst := Void
				end
				if lst /= Void then
					create Result.make_caseless (2)
					from
						lst.start
					until
						lst.after
					loop
						l_session := lst.item
						lst_by_installation := Result [l_session.installation_id]
						if lst_by_installation = Void then
							create {ARRAYED_LIST [ES_CLOUD_SESSION]} lst_by_installation.make (3)
							Result [l_session.installation_id] := lst_by_installation
						end
						lst_by_installation.force (l_session)
						lst.forth
					end
				end
			end
		ensure
			only_concurrent_sessions: Result /= Void implies across Result as ic all not a_current_session.installation_id.is_case_insensitive_equal_general (ic.key) end
			not_empty: Result /= Void implies Result.count > 0
		end

	user_session_sorter: SORTER [ES_CLOUD_SESSION]
		local
			comp: AGENT_EQUALITY_TESTER [ES_CLOUD_SESSION]
		do
			create comp.make (agent (u_sess,v_sess: ES_CLOUD_SESSION): BOOLEAN
					do
						if u_sess.is_active then
							if v_sess.is_active then
								Result := u_sess.last_date < v_sess.last_date
							else
								Result := False
							end
						elseif v_sess.is_active then
							Result := True
						else
							Result := u_sess.last_date < v_sess.last_date
						end
					end
				)
			create {QUICK_SORTER [ES_CLOUD_SESSION]} Result.make (comp)
		end

feature -- Change	

	save_plan (a_plan: ES_CLOUD_PLAN)
		do
			es_cloud_storage.save_plan (a_plan)
		end

	delete_plan (a_plan: ES_CLOUD_PLAN)
		do
			es_cloud_storage.delete_plan (a_plan)
		end

	ping_installation (a_user: ES_CLOUD_USER; a_session: ES_CLOUD_SESSION)
		do
			a_session.set_last_date (create {DATE_TIME}.make_now_utc)
			es_cloud_storage.save_session (a_session)
		end

	end_session (a_user: ES_CLOUD_USER; a_session: ES_CLOUD_SESSION)
		do
			a_session.stop
			es_cloud_storage.save_session (a_session)
		end

	pause_session (a_user: ES_CLOUD_USER; a_session: ES_CLOUD_SESSION)
		do
			if
				not a_session.is_paused
			then
				a_session.pause
				es_cloud_storage.save_session (a_session)
			end
		end

	resume_session (a_user: ES_CLOUD_USER; a_session: ES_CLOUD_SESSION)
		do
			if
				a_session.is_paused or a_session.is_ended
			then
				a_session.resume
				es_cloud_storage.save_session (a_session)
			end
		end

	register_installation (a_license: ES_CLOUD_LICENSE; a_install_id: READABLE_STRING_GENERAL; a_info: detachable READABLE_STRING_GENERAL)
		local
			ins: ES_CLOUD_INSTALLATION
		do
			create ins.make (a_install_id, a_license)
			ins.set_info (a_info)
			es_cloud_storage.save_installation (ins)
		end

feature -- HTML factory

	append_one_line_license_view_to_html (lic: ES_CLOUD_LICENSE; u: ES_CLOUD_USER; es_cloud_module: ES_CLOUD_MODULE; s: STRING_8)
		local
			l_plan: detachable ES_CLOUD_PLAN
			api: CMS_API
		do
			api := cms_api
			l_plan := lic.plan
			s.append ("<div class=%"es-license%">")
			s.append ("<span class=%"license-id%">License ID: </span><span class=%"id%">")
			s.append ("<a href=%"" + api.location_url (es_cloud_module.license_location (lic), Void) + "%">")
			s.append (html_encoded (lic.key))
			s.append ("</a>")
			s.append ("</span> ")
			s.append ("<span class=%"user%">User %"")
			s.append (api.user_html_administration_link (u.cms_user))
			s.append ("%"</span> ")
			s.append ("<span class=%"title%">Plan %"")
			s.append (html_encoded (l_plan.title_or_name))
			s.append ("%"</span> ")
			s.append ("<span class=%"details%">")
			if lic.is_active then
				if attached lic.expiration_date as exp then
					s.append ("<span class=%"expiration%">")
					s.append (lic.days_remaining.out)
					s.append (" days remaining")
					s.append ("</span>")
				else
					s.append ("<span class=%"status%">Active</span>")
				end
			elseif lic.is_fallback then
				s.append ("<span class=%"status%">Fallback license</span>")
			else
				s.append ("<span class=%"status warning%">Expired</span>")
			end
			s.append ("</div>")
		end

	append_short_license_view_to_html (lic: ES_CLOUD_LICENSE; u: ES_CLOUD_USER; es_cloud_module: ES_CLOUD_MODULE; s: STRING_8)
		local
			l_plan: detachable ES_CLOUD_PLAN
			api: CMS_API
		do
			api := cms_api
			l_plan := lic.plan
			s.append ("<div class=%"es-license%">")
			s.append ("<div class=%"header%">")
			s.append ("<div class=%"title%">")
			s.append (html_encoded (l_plan.title_or_name))
			s.append ("</div>")
			s.append ("<div class=%"details%">")
			if lic.is_active then
				if attached lic.expiration_date as exp then
					s.append (lic.days_remaining.out)
					s.append (" days remaining")
				else
					s.append ("Active")
				end
			elseif lic.is_fallback then
				s.append ("Fallback license")
			else
				s.append ("<span class=%"status warning%">Expired</span>")
			end
			s.append ("</div>")
			s.append ("<div class=%"license-id%">License ID: <span class=%"id%">")
			s.append ("<a href=%"" + api.location_url (es_cloud_module.license_location (lic), Void) + "%">")
			s.append (html_encoded (lic.key))
			s.append ("</a>")
			s.append ("</span></div>")
			s.append ("</div>") -- header
			s.append ("<div class=%"details%"><ul>")

			s.append ("</ul></div>")
			s.append ("</div>")
		end


	append_license_to_html (lic: ES_CLOUD_LICENSE; a_user: detachable ES_CLOUD_USER; es_cloud_module: detachable ES_CLOUD_MODULE; s: STRING_8)
		local
			l_plan: detachable ES_CLOUD_PLAN
			inst: ES_CLOUD_INSTALLATION
			api: CMS_API
		do
			api := cms_api
			l_plan := lic.plan
			s.append ("<div class=%"es-license%">")
			s.append ("<div class=%"header%">")
			s.append ("<div class=%"title%">")
			s.append (html_encoded (l_plan.title_or_name))
			s.append ("</div>")
			s.append ("<div class=%"license-id%">License ID: <span class=%"id%">")
			if es_cloud_module /= Void then
				s.append ("<a href=%"" + api.location_url (es_cloud_module.license_location (lic), Void) + "%">")
				s.append (html_encoded (lic.key))
				s.append ("</a>")
			else
				s.append (html_encoded (lic.key))
			end
			s.append ("</span></div>")
			s.append ("</div>") -- header
			s.append ("<div class=%"details%"><ul>")
			if a_user /= Void then
				s.append ("<li class=%"owner%"><span class=%"title%">Owner:</span> ")
				if api.has_permission ({CMS_CORE_MODULE}.perm_view_users) then
					s.append (api.user_html_link (a_user))
				else
					s.append (html_encoded (api.real_user_display_name (a_user)))
				end
				s.append ("</li>")
			end
			s.append ("<li class=%"creation%"><span class=%"title%">Started</span> ")
			s.append (api.date_time_to_string (lic.creation_date))
			s.append ("</li>")
			if lic.is_active then
				if attached lic.expiration_date as exp then
					s.append ("<li class=%"expiration%"><span class=%"title%">Renewal date</span> ")
					s.append (api.date_time_to_string (exp))
					s.append (" (")
					s.append (lic.days_remaining.out)
					s.append (" days remaining)")
					s.append ("</li>")
				else
					s.append ("<li class=%"status success%">ACTIVE</li>")
				end
			elseif lic.is_fallback then
				s.append ("<li class=%"status notice%">Fallback license</li>")
			elseif lic.is_suspended then
				s.append ("<li class=%"status warning%">SUSPENDED</li>")
			else
				s.append ("<li class=%"status warning%">EXPIRED</li>")
			end
			if attached lic.platforms_as_csv_string as l_platforms then
				s.append ("<li class=%"limit%"><span class=%"title%">Limited to platform(s):</span> " + html_encoded (l_platforms) + "</li>")
			end
			if attached lic.version as l_product_version then
				s.append ("<li class=%"limit%"><span class=%"title%">Limited to version:</span> " + html_encoded (l_product_version) + "</li>")
			end
			if attached license_installations (lic) as lst and then not lst.is_empty then
				s.append ("<li class=%"limit%"><span class=%"title%">Installation(s):</span> " + lst.count.out)
				if l_plan.installations_limit > 0 then
					s.append (" / " + l_plan.installations_limit.out + " device(s)")
					if l_plan.installations_limit.to_integer_32 <= lst.count then
						s.append (" (<span class=%"warning%">No more installation available</span>)")
						s.append ("<p>To install on another device, please revoke one the previous installation(s):</p>")
					end
				end

				s.append ("<div class=%"es-installations%"><ul>")
				across
					lst as inst_ic
				loop
					inst := inst_ic.item
					if a_user /= Void then
						s.append ("<li class=%"es-installation discardable%" data-user-id=%"" + a_user.id.out + "%" data-installation-id=%"" + url_encoded (inst.id) + "%" >")
					else
						s.append ("<li class=%"es-installation discardable%">")
					end
					s.append (html_encoded (inst.id))
					s.append ("</li>%N")
				end
				s.append ("</ul></div>")
				s.append ("</li>")
			elseif l_plan.installations_limit > 0 then
				s.append ("<li class=%"limit warning%">Can be installed on: " + l_plan.installations_limit.out + " device(s)</li>")
			end
			if l_plan.platforms_limit > 0 then
				s.append ("<li class=%"limit%">Can be installed on "+ l_plan.platforms_limit.out +" different platforms</li> ")
			end

			if es_cloud_module /= Void then
				s.append ("<li><a href=%"" + api.location_url (es_cloud_module.license_activities_location (lic), Void) + "%">Associated activities...</a> ")
			end
			s.append ("</li>")

			s.append ("</ul></div>")
			s.append ("</div>")
		end

feature -- Email processing

	send_new_license_mail (a_user: detachable CMS_USER; a_customer_name: detachable READABLE_STRING_GENERAL; a_email_addr: READABLE_STRING_8; a_license: ES_CLOUD_LICENSE; a_previous_trial_license: detachable ES_CLOUD_USER_LICENSE ; vars: detachable STRING_TABLE [detachable READABLE_STRING_GENERAL])
		local
			e: CMS_EMAIL
			res: PATH
			s: STRING_8
			msg: READABLE_STRING_8
		do
			create res.make_from_string ("templates")
			if attached cms_api.module_theme_resource_location (module, res.extended ("new_license_email.tpl")) as loc and then attached cms_api.resolved_smarty_template (loc) as tpl then
				tpl.set_value (a_license, "license")
				tpl.set_value (a_license.plan.name, "license_plan_name")
				tpl.set_value (a_license.plan.title_or_name, "license_plan_title")
				tpl.set_value (a_license.key, "license_key")
				if vars /= Void then
					across
						vars as ic
					loop
						if attached ic.item as v then
							tpl.set_value (v, ic.key)
						end
					end
				end
				if a_user /= Void then
					tpl.set_value (a_user, "user")
					tpl.set_value (a_user.email, "user_email")
					tpl.set_value (a_user.name, "user_name")
					tpl.set_value (cms_api.user_display_name (a_user), "customer_name")
				else
					tpl.set_value (a_email_addr, "user_email")
				end
				if a_customer_name /= Void then
					tpl.set_value (html_encoded (a_customer_name), "customer_name")
				end

				msg := tpl.string
			else
				create s.make_empty;
				s.append ("New "+ html_encoded (a_license.plan.title_or_name) +" EiffelStudio license " + utf_8_encoded (a_license.key) + ".%N")
				if a_user = Void then
					s.append ("The license is associated with email %"" + a_email_addr + "%".%NPlease register a new account with that email at " + cms_api.site_url + " .%N")
				else
					s.append ("The license is associated with your account %"" + utf_8_encoded (cms_api.user_display_name (a_user)) + "%" (email %"" + a_email_addr + "%").%NPlease visit " + cms_api.site_url + " .%N")
				end
				msg := s
			end

			e := cms_api.new_html_email (a_email_addr, "New " + utf_8_encoded (a_license.plan.title_or_name) + " EiffelStudio license " + utf_8_encoded (a_license.key), msg)
			cms_api.process_email (e)
		end

	notify_new_license (a_user: detachable CMS_USER; a_customer_name: detachable READABLE_STRING_GENERAL; a_email_addr: detachable READABLE_STRING_8; a_license: ES_CLOUD_LICENSE; a_previous_trial: detachable ES_CLOUD_USER_LICENSE)
		local
			e: CMS_EMAIL
			res: PATH
			s: STRING_8
			msg: READABLE_STRING_8
		do
			create res.make_from_string ("templates")
			if attached cms_api.module_theme_resource_location (module, res.extended ("notify_new_license_email.tpl")) as loc and then attached cms_api.resolved_smarty_template (loc) as tpl then
				tpl.set_value (a_license, "license")
				tpl.set_value (a_license.plan.name, "license_plan_name")
				tpl.set_value (a_license.plan.title_or_name, "license_plan_title")
				tpl.set_value (a_license.key, "license_key")
				if a_user /= Void then
					tpl.set_value (a_user, "user")
					tpl.set_value (a_user.email, "user_email")
					tpl.set_value (a_user.name, "user_name")
					tpl.set_value (cms_api.user_display_name (a_user), "customer_name")
					tpl.set_value (cms_api.user_display_name (a_user), "profile_name")
				else
					tpl.set_value (a_email_addr, "user_email")
				end
				if a_customer_name /= Void then
					tpl.set_value (html_encoded (a_customer_name), "customer_name")
					tpl.set_value (html_encoded (a_customer_name), "profile_name")
				end
				msg := tpl.string
			else
				create s.make_empty;
				s.append ("New "+ html_encoded (a_license.plan.title_or_name) +" EiffelStudio license " + utf_8_encoded (a_license.key) + ".%N")
				if a_user = Void then
					if a_email_addr /= Void then
						s.append ("The license is associated with email %"" + a_email_addr + "%".%N")
					else
						check should_not_occur: False end
						s.append ("The license is associated with no email and no user!%N")
					end
				else
					s.append ("The license is associated with account %"" + utf_8_encoded (cms_api.user_display_name (a_user)) + "%"")
					if a_email_addr /= Void then
						s.append ("(email %"" + a_email_addr + "%")")
					end
					s.append (".%N")
				end
				s.append ("Notification from site " + cms_api.site_url + " .%N")
				msg := s
			end
			e := cms_api.new_html_email (cms_api.setup.site_notification_email, "[NOTIF] New " + utf_8_encoded (a_license.plan.title_or_name) + " EiffelStudio license " + utf_8_encoded (a_license.key), msg)
			cms_api.process_email (e)
		end

	notify_extended_license (a_user: detachable CMS_USER; a_email_addr: detachable READABLE_STRING_8; a_license: ES_CLOUD_LICENSE)
		local
			e: CMS_EMAIL
			res: PATH
			s: STRING_8
			msg: READABLE_STRING_8
		do
			create res.make_from_string ("templates")
			if attached cms_api.module_theme_resource_location (module, res.extended ("notify_extended_license_email.tpl")) as loc and then attached cms_api.resolved_smarty_template (loc) as tpl then
				tpl.set_value (a_license, "license")
				tpl.set_value (a_license.expiration_date, "expiration_date")
				tpl.set_value (a_license.key, "license_key")
				if a_user /= Void then
					tpl.set_value (a_user, "user")
					tpl.set_value (a_user.email, "user_email")
					tpl.set_value (a_user.name, "user_name")
					tpl.set_value (cms_api.user_display_name (a_user), "profile_name")
				else
					tpl.set_value (a_email_addr, "user_email")
				end
				msg := tpl.string
			else
				create s.make_empty;
				s.append ("EiffelStudio license " + utf_8_encoded (a_license.key) + ".%N")
				if attached a_license.expiration_date as dt then
					s.append ("Extended to date: " + cms_api.date_time_to_iso8601_string (dt) + " .%N")
				end
				if a_user = Void then
					if a_email_addr /= Void then
						s.append ("The license is associated with email %"" + a_email_addr + "%" .%N")
					else
						check should_not_occur: False end
						s.append ("The license is associated with no email and no user!%N")
					end
				else
					s.append ("The license is associated with account %"" + utf_8_encoded (cms_api.user_display_name (a_user)) + " %"")
					if a_email_addr /= Void then
						s.append ("(email %"" + a_email_addr + "%")")
					end
					s.append (" .%N")
				end
				s.append ("Notification from site " + cms_api.site_url + " .%N")
				msg := s
			end
			e := cms_api.new_html_email (cms_api.setup.site_notification_email, "[NOTIF] Extended EiffelStudio license " + utf_8_encoded (a_license.key), msg)
			cms_api.process_email (e)
		end

note
	copyright: "2011-2017, Jocelyn Fiat, Javier Velilla, Eiffel Software and others"
	license: "Eiffel Forum License v2 (see http://www.eiffel.com/licensing/forum.txt)"
end

