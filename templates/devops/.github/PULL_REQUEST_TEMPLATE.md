## Summary
<!-- What does this PR do? -->

Closes #<!-- issue number -->

## Type of change
- [ ] New/updated Terraform module
- [ ] New/updated Helm chart
- [ ] Dockerfile change
- [ ] CI/CD pipeline change
- [ ] YAML config change
- [ ] Documentation update
- [ ] Other: ___

## Changes made
-
-

## Validation
- [ ] `yamllint .` passes locally
- [ ] `terraform fmt -recursive` applied
- [ ] `terraform validate` passes locally
- [ ] `tflint --recursive` passes locally
- [ ] `helm lint` passes locally (if Helm changes)
- [ ] Pre-commit hooks pass (`pre-commit run --all-files`)
- [ ] No hardcoded secrets or credentials

## Checklist
- [ ] Terraform state backend is NOT configured locally (CI uses `-backend=false`)
- [ ] I have NOT committed `.terraform/`, `.tfstate`, or secrets
- [ ] The CI pipeline passes (check the Actions tab after pushing)
