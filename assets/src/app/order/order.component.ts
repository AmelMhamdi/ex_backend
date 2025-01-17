
import {Component} from '@angular/core'
import {ActivatedRoute, Router} from '@angular/router'

import {S3Configuration} from '../models/s3'

import {WorkflowService} from '../services/workflow.service'
import {S3Service} from '../services/s3.service'

let Evaporate = require('evaporate');
let crypto = require('crypto');

@Component({
  selector: 'order-component',
  templateUrl: 'order.component.html',
  styleUrls: ['./order.component.less'],
})

export class OrderComponent {
  is_new_order: boolean = false
  order_id: number
  mp4_file: any
  ttml_file: any
  video_identifier: string = "0b0651d8-34b9-4724-b36a-96a3e1f71ef8"
  mp4_percent_uploaded = 0
  ttml_percent_uploaded = 0
  completed = 0
  s3_configuration: S3Configuration

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private s3Service: S3Service,
    private workflowService: WorkflowService
  ) {}

  ngOnInit() {
    this.route
      .params.subscribe(params => {
        if(params['id'] == 'new') {
          this.is_new_order = true
        } else {
          this.order_id = params['id']
        }
      })

    this.s3Service.getConfiguration()
      .subscribe(s3_configuration => {
        this.s3_configuration = s3_configuration
      })
  }

  upload() {
    var mp4_file = this.mp4_file.files[0]
    var ttml_file = this.ttml_file.files[0]
    var current = this
    this.mp4_percent_uploaded = 0;
    this.ttml_percent_uploaded = 0;
    current.completed = 0;

    var config = {
      signerUrl: '/api/s3_signer',
      aws_key: this.s3_configuration.access_key,
      bucket: 'subtil',
      aws_url: this.s3_configuration.url,
      computeContentMd5: true,
      cryptoMd5Method: function (data) {
        console.log(data, crypto.createHash('md5'))
        var buffer = new Buffer(data)
        return crypto.createHash('md5').update(buffer).digest('base64');
      },
      cryptoHexEncodedHash256: function (data) { return crypto.createHash('sha256').update(data).digest('hex'); },
    };

    var uploader = Evaporate.create(config)
      .then(function (evaporate) {
        var mp4Config = {
          name: mp4_file.name,
          file: mp4_file,
          progress: function (progressValue) {
            current.mp4_percent_uploaded = progressValue * 100;
          },
          complete: function (_xhr, awsKey) {
            current.completed += 1
            if(current.completed == 2) {
              current.launch_workflow(mp4_file.name, ttml_file.name)
            }
          },
        }
        var ttmlConfig = {
          name: ttml_file.name,
          file: ttml_file,
          progress: function (progressValue) {
            current.ttml_percent_uploaded = progressValue * 100;
          },
          complete: function (_xhr, awsKey) {
            current.completed += 1
            if(current.completed == 2) {
              current.launch_workflow(mp4_file.name, ttml_file.name)
            }
          },
        }
        var overrides = {
          bucket: 'subtil'
        }

        evaporate.add(mp4Config, overrides)
          .then(function (awsObjectKey) {
            console.log('File successfully uploaded to:', awsObjectKey);
          },
          function (reason) {
            console.log('File did not upload sucessfully:', reason);
          })

        evaporate.add(ttmlConfig, overrides)
          .then(function (awsObjectKey) {
            console.log('File successfully uploaded to:', awsObjectKey);
          },
          function (reason) {
            console.log('File did not upload sucessfully:', reason);
          })
      })
  }

  launch_workflow(mp4_filename, ttml_filename) {
    var params = new Array(
      "credential_aws_secret_key=MEDIAIO_BUCKET_SUBTIL",
      "credential_aws_secret_key=MEDIAIO_BUCKET_SUBTIL",
      "hostname=" + this.s3_configuration.url,
      "region=" + this.s3_configuration.region,
    ); 

    var source_mp4_url = "s3://" + this.s3_configuration.bucket + "/" + mp4_filename + "?" + params.join("&")
    var source_ttml_url = "s3://" + this.s3_configuration.bucket + "/" + ttml_filename + "?" + params.join("&")
    var output_url = "s3://" + this.s3_configuration.bucket + "/output.ttml?" + params.join("&")

    this.workflowService.getStandaloneWorkflowDefinition("ftv_acs_standalone", source_mp4_url, source_ttml_url, output_url)
      .subscribe(workflowDefinition => {
        workflowDefinition['reference'] = output_url

        this.workflowService.createWorkflow(workflowDefinition)
        .subscribe(response => {
          console.log(response)
        })
    })
  }

  start_via_uuid() {
    var parameters = {
      "reference": this.video_identifier
    }

    this.workflowService.createSpecificWorkflow("ftv-acs-standalone", this.video_identifier)
    .subscribe(response => {
      this.router.navigate(['/orders'], { queryParams: {order_id: response.workflow_id} })
    })
  }
}
