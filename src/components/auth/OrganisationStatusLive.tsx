"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

/**
 * Keeps the account page in sync with the user's organisations (CLAUDE.md › UX rules: updates
 * that concern the user arrive in real time). Realtime applies the subscriber's RLS, so a member
 * only ever receives changes to organisations they are allowed to read.
 * Renders nothing visible; exposes its state as data attributes for tests.
 */
export function OrganisationStatusLive({ orgIds }: { orgIds: string[] }) {
  const router = useRouter();
  const [status, setStatus] = useState<"connecting" | "subscribed" | "error">("connecting");
  const [events, setEvents] = useState(0);
  const key = orgIds.join(",");

  useEffect(() => {
    if (!key) return;
    const supabase = createClient();
    let cancelled = false;
    const channel = supabase.channel(`organisations:${key}`, {
      config: { postgres_changes_options: { wait: true } },
    });
    for (const id of key.split(",")) {
      channel.on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "organizations", filter: `id=eq.${id}` },
        () => {
          setEvents((n) => n + 1);
          router.refresh();
        },
      );
    }
    (async () => {
      await supabase.realtime.setAuth();
      if (cancelled) return;
      channel.subscribe((s) => {
        if (s === "SUBSCRIBED") setStatus("subscribed");
        if (s === "CHANNEL_ERROR" || s === "TIMED_OUT") setStatus("error");
      });
    })();
    return () => {
      cancelled = true;
      supabase.removeChannel(channel);
    };
  }, [key, router]);

  return <li hidden data-testid="org-live" data-realtime={status} data-realtime-events={events} />;
}
