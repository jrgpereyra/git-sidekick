"""Smoke test del servidor MCP real por stdio."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from contextlib import asynccontextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT / "mcp" / "server.py"

from mcp import ClientSession, StdioServerParameters  # noqa: E402
from mcp.client.stdio import stdio_client  # noqa: E402

sys.path.insert(0, str(ROOT / "mcp" / "tests"))
from helpers import git, init_repo, write_file  # noqa: E402

EXPECTED_TOOLS = {
    "git_sidekick_status",
    "git_sidekick_info",
    "git_sidekick_list_branches",
    "git_sidekick_list_snapshots",
}


class StdioTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="sidekick-mcp-stdio-")
        self.tmp = Path(self._tmp.name)
        self.repo = init_repo(self.tmp / "repo")
        git(self.repo, "branch", "dev")
        git(self.repo, "tag", "work/2026-01-01_10-00")
        write_file(self.repo / "pendiente.txt", "sin guardar")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    @asynccontextmanager
    async def client(self):
        env = {
            key: value
            for key, value in os.environ.items()
            if key != "GIT_SIDEKICK_ALLOWED_ROOTS"
        }
        env["GIT_SIDEKICK_REPO"] = str(self.repo)
        params = StdioServerParameters(
            command=sys.executable,
            args=[str(SERVER)],
            env=env,
            cwd=str(ROOT),
        )
        async with stdio_client(params) as (read_stream, write_stream):
            async with ClientSession(read_stream, write_stream) as session:
                await session.initialize()
                yield session

    async def call(self, session: ClientSession, name: str, arguments: dict | None = None) -> dict:
        result = await session.call_tool(name, arguments or {})
        self.assertFalse(
            result.isError,
            msg=f"La tool {name} devolvió error: {result.content}",
        )
        self.assertIsNotNone(result.structuredContent)
        return result.structuredContent

    async def test_lista_exactamente_cuatro_tools_readonly(self) -> None:
        async with self.client() as session:
            result = await session.list_tools()

        names = {tool.name for tool in result.tools}
        self.assertEqual(names, EXPECTED_TOOLS)
        for tool in result.tools:
            self.assertTrue(tool.annotations.readOnlyHint)
            self.assertIsNotNone(tool.outputSchema)
            self.assertIn("repo_path", tool.inputSchema.get("properties", {}))

    async def test_status_usa_repo_del_entorno(self) -> None:
        async with self.client() as session:
            data = await self.call(session, "git_sidekick_status")

        self.assertTrue(data["ok"])
        self.assertEqual(data["tool"], "git_sidekick_status")
        self.assertEqual(data["repo"], str(self.repo.resolve()))
        self.assertEqual(data["data"]["branch"], "main")
        self.assertTrue(data["data"]["dirty"])

    async def test_info_ramas_y_snapshots(self) -> None:
        async with self.client() as session:
            info = await self.call(session, "git_sidekick_info")
            branches = await self.call(session, "git_sidekick_list_branches")
            snapshots = await self.call(session, "git_sidekick_list_snapshots")

        self.assertTrue(info["data"]["session"]["active"] is False)
        self.assertEqual(info["data"]["snapshots_count"], 1)
        self.assertTrue(branches["data"]["total"] >= 2)
        self.assertEqual(snapshots["data"]["total"], 1)
        self.assertEqual(
            snapshots["data"]["snapshots"][0]["tag"], "work/2026-01-01_10-00"
        )

    async def test_error_de_repo_inexistente(self) -> None:
        async with self.client() as session:
            result = await session.call_tool(
                "git_sidekick_status", {"repo_path": str(self.tmp / "no-existe")}
            )

        self.assertTrue(result.isError)
        texts = [
            item.text
            for item in result.content
            if getattr(item, "text", None)
        ]
        self.assertIn("NOT_A_REPO", "\n".join(texts))


if __name__ == "__main__":
    unittest.main()
