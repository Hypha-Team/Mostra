"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

/**
 * Keeps the account page in sync with the user's organisations (CLAUDE.md › UX rules: updates
 * that concern the user arrive in real time). Each organisation has a PRIVATE Realtime channel
 * ("organization:<id>"): the database broadcasts status changes on it, and an RLS policy on
 * realtime.messages lets only that organisation's members join.
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
    const ids = key.split(",");
    const channels = ids.map((id) =>
      supabase
        .channel(`organization:${id}`, { config: { private: true } })
        .on("broadcast", { event: "status" }, () => {
          setEvents((n) => n + 1);
          router.refresh();
        }),
    );
    let cancelled = false;
    let joined = 0;
    (async () => {
      await supabase.realtime.setAuth();
      if (cancelled) return;
      for (const channel of channels) {
        channel.subscribe((s) => {
          if (s === "SUBSCRIBED" && ++joined === channels.length) setStatus("subscribed");
          if (s === "CHANNEL_ERROR" || s === "TIMED_OUT") setStatus("error");
        });
      }
    })();
    return () => {
      cancelled = true;
      channels.forEach((c) => supabase.removeChannel(c));
    };
  }, [key, router]);

  return <li hidden data-testid="org-live" data-realtime={status} data-realtime-events={events} />;
}
