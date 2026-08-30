UPDATE user_profiles AS profile
SET display_name = 'Paktly member', updated_at = now()
FROM auth_identities AS identity
WHERE identity.user_id = profile.user_id
  AND identity.provider = 'SOCKETFI'
  AND profile.display_name ~* '^socketfi-[0-9]+$';
