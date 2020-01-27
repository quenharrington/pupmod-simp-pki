require 'spec_helper_acceptance'

test_name 'pki STIG enforcement of simp profile'

describe 'pki STIG enforcement of simp profile' do

  let(:manifest) {
    <<-EOS
  file { '/etc/pki/simp':
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    seltype => 'cert_t',
    recurse => true,
    before  => Pki_cert_sync['/etc/pki/simp/cacerts']
  }
  file { '/etc/pki/simp/cacerts':
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    seltype => 'cert_t',
    recurse => true,
  }
  pki_cert_sync { '/etc/pki/simp/cacerts':
    source => '/etc/pki/simp-testing/pki/cacerts/',
    purge  => true,
  }
    EOS
  }

  let(:hieradata) { <<-EOF
---
simp_options::pki: true
simp_options::pki::source: '/etc/pki/simp-testing/pki'

compliance_markup::enforcement:
  - disa_stig
  EOF
  }

  hosts.each do |host|

    let(:hiera_yaml) { <<-EOM
---
version: 5
hierarchy:
  - name: Common
    path: common.yaml
  - name: Compliance
    lookup_key: compliance_markup::enforcement
defaults:
  data_hash: yaml_data
  datadir: "#{hiera_datadir(host)}"
      EOM
    }

    context 'when enforcing the STIG' do
      it 'should work with no errors' do
        create_remote_file(host, host.puppet['hiera_config'], hiera_yaml)
        write_hieradata_to(host, hieradata)

        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should reboot for audit updates' do
        host.reboot

        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, :catch_changes => true)
      end
    end
  end
end
