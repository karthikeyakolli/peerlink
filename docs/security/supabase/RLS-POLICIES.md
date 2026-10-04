# Row Level Security (RLS) Policies

All tables exposed to the Supabase PostgREST data API enforce PostgreSQL Row Level Security (RLS) with least privilege principles.

## 1. `device_registry`

### Public Key Discovery (SELECT)
Authenticated peers can look up public identity keys of active, unrevoked devices:
```sql
CREATE POLICY "Authenticated users can query public identity keys"
    ON public.device_registry FOR SELECT
    TO authenticated
    USING (is_revoked = FALSE);
```

### Device Management (INSERT / UPDATE / DELETE)
Only the authenticated owner (`auth.uid() = user_id`) can register, update, or revoke their devices:
```sql
CREATE POLICY "Users can insert their own devices"
    ON public.device_registry FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own devices"
    ON public.device_registry FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own devices"
    ON public.device_registry FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);
```

---

## 2. `device_presence`

### Upsert Presence
Only the owner of the device can update its presence heartbeat and candidate endpoints:
```sql
CREATE POLICY "Device owner can upsert presence"
    ON public.device_presence FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.device_registry dr
            WHERE dr.device_id = public.device_presence.device_id
              AND dr.user_id = auth.uid()
        )
    );
```

### View Presence
Authenticated users can inspect presence of registered devices:
```sql
CREATE POLICY "Authenticated users can view device presence"
    ON public.device_presence FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.device_registry dr
            WHERE dr.device_id = public.device_presence.device_id
              AND dr.is_revoked = FALSE
        )
    );
```

---

## 3. `signaling_messages`

### Senders
A sender can only insert signaling messages if the `sender_peer_id` belongs to an active device owned by the authenticated user:
```sql
CREATE POLICY "Senders can insert signaling messages"
    ON public.signaling_messages FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.device_registry dr
            WHERE dr.peer_id = public.signaling_messages.sender_peer_id
              AND dr.user_id = auth.uid()
              AND dr.is_revoked = FALSE
        )
    );
```

### Recipients
Only the intended recipient can read, update, or delete their signaling messages:
```sql
CREATE POLICY "Recipients can read their signaling messages"
    ON public.signaling_messages FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.device_registry dr
            WHERE dr.peer_id = public.signaling_messages.recipient_peer_id
              AND dr.user_id = auth.uid()
              AND dr.is_revoked = FALSE
        )
        AND expires_at >= NOW()
    );
```

---

## 4. `control_audit_log`
Append-only for the authenticated user:
```sql
CREATE POLICY "Users can append audit logs"
    ON public.control_audit_log FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own audit logs"
    ON public.control_audit_log FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);
```
