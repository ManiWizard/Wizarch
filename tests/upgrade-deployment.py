"""Exercise deployment rollback and conflict handling entirely in temporary files."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('deployment',Path(__file__).resolve().parents[1]/'scripts/deploy-upgrade.py')
deployment=importlib.util.module_from_spec(spec);spec.loader.exec_module(deployment)

class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.source=self.root/'source';self.source.write_bytes(b'new');self.source.chmod(0o640)
        self.old=self.root/'installed';self.old.write_bytes(b'old');self.old.chmod(0o600)
        self.added=self.root/'new-file';self.manifest=self.root/'release.json'
        deployment.prepare(self.manifest,[{'source':str(self.source),'target':str(self.old)},{'source':str(self.source),'target':str(self.added)}])
    def test_apply_restore_reapply_and_permissions(self):
        deployment.execute(self.manifest)
        self.assertEqual(self.old.read_bytes(),b'new');self.assertEqual(self.old.stat().st_mode&0o777,0o640)
        deployment.execute(self.manifest,True)
        self.assertEqual(self.old.read_bytes(),b'old');self.assertEqual(self.old.stat().st_mode&0o777,0o600)
        self.assertFalse(self.added.exists());deployment.execute(self.manifest)
    def test_all_targets_checked_before_first_write(self):
        self.added.write_bytes(b'user edit')
        with self.assertRaises(ValueError):deployment.execute(self.manifest)
        self.assertEqual(self.old.read_bytes(),b'old')
    def test_restore_refuses_unrelated_edit(self):
        deployment.execute(self.manifest);self.old.write_bytes(b'later edit')
        with self.assertRaises(ValueError):deployment.execute(self.manifest,True)
        self.assertTrue(self.added.exists());self.assertEqual(self.old.read_bytes(),b'later edit')
    def test_partial_deployment_can_restore(self):
        self.old.write_bytes(b'new');self.old.chmod(0o640)
        deployment.execute(self.manifest,True)
        self.assertEqual(self.old.read_bytes(),b'old');self.assertFalse(self.added.exists())
    def test_corrupt_payload_checked_before_first_write(self):
        import json
        m=json.loads(self.manifest.read_text());Path(m['entries'][1]['after']['payload']).write_bytes(b'corrupt')
        with self.assertRaises(ValueError):deployment.execute(self.manifest)
        self.assertEqual(self.old.read_bytes(),b'old')
    def test_symlink_refused(self):
        self.added.symlink_to(self.source)
        with self.assertRaises(ValueError):deployment.execute(self.manifest)

if __name__=='__main__':unittest.main()
