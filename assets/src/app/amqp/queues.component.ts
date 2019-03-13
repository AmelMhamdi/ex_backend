import {Component} from '@angular/core'
import {interval}   from 'rxjs'

import {AmqpService} from '../services/amqp.service'
import {Queue} from '../models/queue'

@Component({
  selector: 'amqp-queues',
  templateUrl: 'queues.component.html',
  styleUrls: ['./queues.component.less'],
})

export class QueuesComponent {

  queues: Queue[]

  constructor(
    private amqpService: AmqpService
  ) {}

  ngOnInit() {
    this.getQueues()

    const updater = interval(5000);
    updater.subscribe(n =>
      this.getQueues()
    );
  }

  getQueues(): void {
    this.amqpService.getQueues()
    .subscribe(queuePage => {
      if (queuePage){
        var all_queues = []
        queuePage.queues.forEach(function(queue){
          if(queue.messages_unacknowledged > 0 || (queue.messages - queue.messages_unacknowledged) > 0) {
            // console.log(queue)
            all_queues.push(queue)
          }
        })

        this.queues = all_queues
      }
    })
  }
}
